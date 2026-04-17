
import pandas as pd
import psycopg2
from psycopg2 import sql
from psycopg2.extras import execute_values
import numpy as np


# DATABASE CONNECTION CONFIGURATION

DB_CONFIG = {
    'host': 'localhost',        
    'database': 'saas_churn_analytics',
    'user': 'postgres',         
    'password': 'omen',  
    'port': 5432               
}


CSV_PATH = '../../data/processed/churn_data_engineered.csv'



print("LOADING CSV DATA")

df = pd.read_csv(CSV_PATH)
print(f" Loaded {len(df):,} rows from CSV")
print(f"   Columns: {len(df.columns)}")



print("CONNECTING TO POSTGRESQL")


try:
    conn = psycopg2.connect(**DB_CONFIG)
    cursor = conn.cursor()
    print(f"Connected to database: {DB_CONFIG['database']}")
except Exception as e:
    print(f"Connection failed: {e}")
    print("\nTroubleshooting:")
    print("1. Check if PostgreSQL is running")
    print("2. Verify your password in DB_CONFIG")
    print("3. Confirm database name is 'saas_churn_analytics'")
    exit(1)


# CLEAR EXISTING DATA (for clean re-runs)

print("STEP 3: CLEARING EXISTING DATA")

try:
    
    cursor.execute("DELETE FROM fact_customer_metrics;")
    cursor.execute("DELETE FROM dim_subscription;")
    cursor.execute("DELETE FROM dim_customer;")
    conn.commit()
    print(" Existing data cleared")
except Exception as e:
    print(f" Warning during cleanup: {e}")
    conn.rollback()



print("LOADING dim_customer")


# Extract unique customers with their demographics
customers = df[['CustomerID', 'Age', 'Gender']].drop_duplicates('CustomerID')

# Convert to list of tuples for bulk insert
customer_data = [
    (int(row['CustomerID']), int(row['Age']), row['Gender'])
    for _, row in customers.iterrows()
]


insert_customer_query = """
    INSERT INTO dim_customer (customer_id, age, gender)
    VALUES %s
    ON CONFLICT (customer_id) DO NOTHING;
"""

try:
    execute_values(cursor, insert_customer_query, customer_data)
    conn.commit()
    print(f" Inserted {len(customer_data):,} customers into dim_customer")
except Exception as e:
    print(f" Error loading customers: {e}")
    conn.rollback()
    exit(1)


print(" LOADING dim_subscription")


# Extract subscription information
subscriptions = df[['CustomerID', 'Subscription Type', 'Contract Length']].drop_duplicates('CustomerID')

subscription_data = [
    (int(row['CustomerID']), row['Subscription Type'], row['Contract Length'])
    for _, row in subscriptions.iterrows()
]

insert_subscription_query = """
    INSERT INTO dim_subscription (customer_id, subscription_type, contract_length)
    VALUES %s;
"""

try:
    execute_values(cursor, insert_subscription_query, subscription_data)
    conn.commit()
    print(f" Inserted {len(subscription_data):,} subscriptions into dim_subscription")
except Exception as e:
    print(f" Error loading subscriptions: {e}")
    conn.rollback()
    exit(1)


print(" LOADING fact_customer_metrics")

# Replace NaN with None for proper NULL handling
df_clean = df.replace({np.nan: None})

# Prepare metrics data
metrics_data = []
for _, row in df_clean.iterrows():
    metrics_data.append((
        int(row['CustomerID']),
        
        # Behavioral metrics
        int(row['Tenure']),
        int(row['Usage Frequency']),
        int(row['Support Calls']),
        int(row['Payment Delay']),
        int(row['Last Interaction']),
        
        # Financial metrics
        float(row['Total Spend']),
        float(row['MRR']),
        float(row['CLV_Actual']),
        float(row['CLV_Predicted']),
        float(row['CLV_Lost']),
        
        # Health & risk scores
        float(row['Health_Score']),
        row['Health_Category'],
        float(row['Recency_Score']),
        
        # Segmentation
        row['Engagement_Tier'],
        row['Payment_Risk'],
        bool(row['Payment_Risk_Flag']),
        row['Interaction_Recency'],
        row['Cohort'],
        
        # Target variable
        bool(row['Churn'])
    ))

insert_metrics_query = """
    INSERT INTO fact_customer_metrics (
        customer_id,
        tenure_months, usage_frequency, support_calls, payment_delay_count, last_interaction_days,
        total_spend, mrr, clv_actual, clv_predicted, clv_lost,
        health_score, health_category, recency_score,
        engagement_tier, payment_risk, payment_risk_flag, interaction_recency, cohort,
        has_churned
    )
    VALUES %s;
"""

try:
    # Insert in batches for performance (1000 rows at a time)
    batch_size = 1000
    total_inserted = 0
    
    for i in range(0, len(metrics_data), batch_size):
        batch = metrics_data[i:i+batch_size]
        execute_values(cursor, insert_metrics_query, batch)
        total_inserted += len(batch)
        print(f"   Progress: {total_inserted:,}/{len(metrics_data):,} rows", end='\r')
    
    conn.commit()
    print(f"\n Inserted {total_inserted:,} records into fact_customer_metrics")
except Exception as e:
    print(f"\n Error loading metrics: {e}")
    conn.rollback()
    exit(1)


print(" DATA VALIDATION")


# Check row counts
cursor.execute("SELECT COUNT(*) FROM dim_customer;")
customer_count = cursor.fetchone()[0]

cursor.execute("SELECT COUNT(*) FROM dim_subscription;")
subscription_count = cursor.fetchone()[0]

cursor.execute("SELECT COUNT(*) FROM fact_customer_metrics;")
metrics_count = cursor.fetchone()[0]

print(f" dim_customer: {customer_count:,} rows")
print(f" dim_subscription: {subscription_count:,} rows")
print(f" fact_customer_metrics: {metrics_count:,} rows")


print("BUSINESS SUMMARY (from view)")


cursor.execute("SELECT * FROM vw_business_summary;")
summary = cursor.fetchone()

if summary:
    print(f"Total Customers: {summary[0]:,}")
    print(f"Churned Customers: {summary[1]:,}")
    print(f"Churn Rate: {summary[2]}%")
    print(f"Total MRR: ${summary[3]:,.2f}")
    print(f"Avg MRR: ${summary[4]:,.2f}")
    print(f"Total Revenue Lost: ${summary[5]:,.2f}")
    print(f"Avg Health Score: {summary[6]}")
    print(f"High Risk Customers: {summary[7]:,}")


cursor.close()
conn.close()


print(" DATA LOADING COMPLETE !")