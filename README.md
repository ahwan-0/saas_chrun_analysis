# SaaS Customer Churn Prediction & Revenue Optimization

**Business Problem:** Predict which customers will churn next month and quantify revenue impact to enable proactive retention strategies.

**Project Type:** End-to-End Data Analytics (Data Engineering,  Business Intelligence, Predictive Analytics)


---

##  Executive Summary

This project analyzes customer churn patterns for a SaaS subscription business experiencing a **47.37% churn rate** (9x the industry average). Through feature engineering, SQL analytics, and interactive dashboards, I identified :

- **$14M in potential revenue loss** from churned customers
- **Payment delays** as the primary churn driver (+45.88% churn probability)
- **Veteran Cliff phenomenon**: 55.91% of customers with 25+ months tenure churn (vs 34.96% for new customers)
- **36,911 high-risk customers** representing 57% of the customer base

**Business Impact:** A 10% reduction in churn among critical customers would save **$1.62M annually**.

---

##  Business Questions Answered

1. **What is our current churn rate and revenue impact?**
   - 47.37% churn rate across 64,374 customers
   - $2.48M total MRR, $880K from churned customers
   - $14M in lost lifetime value

2. **Which customer segments are at highest risk?**
   - "Critical" health segment: 32,622 customers (50.7% of base), 64.15% churn rate
   - Customers with 3+ payment delays: 50.27% churn vs 10% baseline

3. **When in the customer lifecycle does churn occur?**
   - Counter-intuitive finding: Veteran customers (25+ months) churn at 55.91%
   - Only 28.58% of customers survive past month 24
   - New customers (0-3 months) have lower churn at 34.96%

4. **What factors predict churn?**
   - Payment delays: +45.88% churn increase
   - High support calls (5+): +27.93% churn increase
   - Low engagement: +16.38% churn increase

5. **Which customers should we prioritize for retention?**
   - Top 25% by MRR generate 73% of revenue but only have 29.79% churn
   - 100 high-value at-risk customers identified with composite risk scores

---

## 🛠️ Technical Stack

**Languages & Tools:**
- **Python 3.11** - Data processing, feature engineering
- **PostgreSQL 16** - Analytics database, dimensional modeling
- **Power BI Desktop** - Interactive dashboards, data visualization
- **SQL** - Business logic, aggregations, window functions
- **Git** - Version control

**Key Libraries:**
- pandas, numpy - Data manipulation
- psycopg2 - Database connectivity
- matplotlib, seaborn - Exploratory visualization

---

## 📦 Dataset Information

**Source:** [Customer Churn Dataset by Muhammad Shahid Azeem](https://www.kaggle.com/datasets/muhammadshahidazeem/customer-churn-dataset)

**Size:** 64,374 customers (training set)

**Features:**
- Demographics: Age, Gender
- Subscription: Type (Basic/Standard/Premium), Contract Length (Monthly/Quarterly/Annual)
- Behavior: Tenure, Usage Frequency, Support Calls, Payment Delays
- Financial: Total Spend
- Target: Churn (Binary)

**Engineered Features (8 new):**
- MRR, CLV (Actual/Predicted/Lost)
- Health Score, Engagement Tier
- Payment Risk, Cohort, Recency Score


