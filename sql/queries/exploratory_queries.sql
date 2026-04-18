-- Overall Business Snapshot

SELECT 
    COUNT(*) as total_customers,
    COUNT(*) FILTER (WHERE has_churned = TRUE) as churned_customers,
    COUNT(*) FILTER (WHERE has_churned = FALSE) as active_customers,
    ROUND(AVG(CASE WHEN has_churned = TRUE THEN 1 ELSE 0 END) * 100, 2) as churn_rate_pct,
    ROUND(SUM(mrr), 2) as total_mrr,
    ROUND(SUM(mrr) FILTER (WHERE has_churned = FALSE), 2) as active_mrr,
    ROUND(SUM(clv_lost), 2) as total_revenue_lost
FROM fact_customer_metrics;


-- Churn by subscription type 

SELECT 
    s.subscription_type,
    COUNT(*) as total_customers,
    SUM(CASE WHEN m.has_churned THEN 1 ELSE 0 END) as churned_customers,
    ROUND(AVG(CASE WHEN m.has_churned THEN 1 ELSE 0 END) * 100, 2) as churn_rate_pct,
    ROUND(AVG(m.mrr), 2) as avg_mrr,
    ROUND(SUM(m.mrr), 2) as total_mrr,
    ROUND(SUM(m.clv_lost), 2) as revenue_lost
FROM fact_customer_metrics m
JOIN dim_subscription s ON m.customer_id = s.customer_id
GROUP BY s.subscription_type
ORDER BY churn_rate_pct DESC;


-- Churn by contract length

SELECT 
    s.contract_length,
    COUNT(*) as total_customers,
    SUM(CASE WHEN m.has_churned THEN 1 ELSE 0 END) as churned,
    ROUND(AVG(CASE WHEN m.has_churned THEN 1 ELSE 0 END) * 100, 2) as churn_rate_pct,
    ROUND(AVG(m.tenure_months), 1) as avg_tenure_months,
    ROUND(AVG(m.clv_actual), 2) as avg_clv
FROM fact_customer_metrics m
JOIN dim_subscription s ON m.customer_id = s.customer_id
GROUP BY s.contract_length
ORDER BY churn_rate_pct ASC;



-- Rvenue Impact by Health Category

SELECT 
    health_category,
    COUNT(*) as customer_count,
    ROUND(SUM(mrr), 2) as total_mrr,
    ROUND(AVG(mrr), 2) as avg_mrr,
    ROUND(SUM(mrr) / (SELECT SUM(mrr) FROM fact_customer_metrics) * 100, 2) as pct_of_total_mrr,
    SUM(CASE WHEN has_churned THEN 1 ELSE 0 END) as churned_count,
    ROUND(AVG(CASE WHEN has_churned THEN 1 ELSE 0 END) * 100, 2) as churn_rate_pct
FROM fact_customer_metrics
GROUP BY health_category
ORDER BY 
    CASE health_category
        WHEN 'Churning' THEN 1
        WHEN 'Critical' THEN 2
        WHEN 'At Risk' THEN 3
        WHEN 'Healthy' THEN 4
    END;


-- Customer Segments (High Value vs Low Value)

WITH customer_segments AS (
    SELECT 
        customer_id,
        mrr,
        has_churned,
        health_category,
        NTILE(4) OVER (ORDER BY mrr DESC) as mrr_quartile
        -- NTILE(4) = divide into 4 equal groups (top 25%, next 25%, etc)
    FROM fact_customer_metrics
)
SELECT 
    CASE mrr_quartile
        WHEN 1 THEN 'Top 25% (Whales)'
        WHEN 2 THEN 'Mid-High 25%'
        WHEN 3 THEN 'Mid-Low 25%'
        WHEN 4 THEN 'Bottom 25% (Barnacles)'
    END as segment,
    COUNT(*) as customers,
    ROUND(AVG(mrr), 2) as avg_mrr,
    ROUND(SUM(mrr), 2) as total_mrr,
    ROUND(AVG(CASE WHEN has_churned THEN 1 ELSE 0 END) * 100, 2) as churn_rate_pct
FROM customer_segments
GROUP BY mrr_quartile
ORDER BY mrr_quartile;


-- Cohort Analysis - When Do Customers Churn?


SELECT 
    cohort,
    COUNT(*) as total_customers,
    SUM(CASE WHEN has_churned THEN 1 ELSE 0 END) as churned,
    ROUND(AVG(CASE WHEN has_churned THEN 1 ELSE 0 END) * 100, 2) as churn_rate_pct,
    ROUND(AVG(tenure_months), 1) as avg_tenure,
    ROUND(AVG(mrr), 2) as avg_mrr,
    ROUND(SUM(clv_lost), 2) as revenue_lost
FROM fact_customer_metrics
GROUP BY cohort
ORDER BY 
    CASE cohort
        WHEN 'New (0-3m)' THEN 1
        WHEN 'Growing (4-12m)' THEN 2
        WHEN 'Mature (13-24m)' THEN 3
        WHEN 'Veteran (25m+)' THEN 4
    END;

-- Payment Risk analysis

SELECT 
    payment_risk,
    COUNT(*) as customers,
    ROUND(AVG(CASE WHEN has_churned THEN 1 ELSE 0 END) * 100, 2) as churn_rate_pct,
    ROUND(AVG(payment_delay_count), 1) as avg_delays,
    ROUND(SUM(mrr), 2) as total_mrr_at_risk
FROM fact_customer_metrics
GROUP BY payment_risk
ORDER BY 
    CASE payment_risk
        WHEN 'High Risk' THEN 1
        WHEN 'Low Risk' THEN 2
        WHEN 'No Risk' THEN 3
    END;

-- Engagemnet vs Churn Correlation

SELECT 
    engagement_tier,
    COUNT(*) as customers,
    ROUND(AVG(usage_frequency), 1) as avg_usage,
    ROUND(AVG(CASE WHEN has_churned THEN 1 ELSE 0 END) * 100, 2) as churn_rate_pct,
    ROUND(AVG(health_score), 1) as avg_health_score
FROM fact_customer_metrics
GROUP BY engagement_tier
ORDER BY 
    CASE engagement_tier
        WHEN 'Low' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'High' THEN 3
    END;


-- Save the results

CREATE OR REPLACE VIEW vw_churn_by_subscription AS
SELECT 
    s.subscription_type,
    COUNT(*) as total_customers,
    SUM(CASE WHEN m.has_churned THEN 1 ELSE 0 END) as churned,
    ROUND(AVG(CASE WHEN m.has_churned THEN 1 ELSE 0 END) * 100, 2) as churn_rate_pct,
    ROUND(SUM(m.mrr), 2) as total_mrr
FROM fact_customer_metrics m
JOIN dim_subscription s ON m.customer_id = s.customer_id
GROUP BY s.subscription_type;

