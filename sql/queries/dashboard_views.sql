
-- VIEW 1: Executive Summary KPIs

CREATE OR REPLACE VIEW vw_executive_kpis AS
SELECT 
    COUNT(*) as total_customers,
    COUNT(*) FILTER (WHERE has_churned = FALSE) as active_customers,
    COUNT(*) FILTER (WHERE has_churned = TRUE) as churned_customers,
    ROUND(AVG(CASE WHEN has_churned = TRUE THEN 1 ELSE 0 END) * 100, 2) as churn_rate_pct,
    ROUND(SUM(mrr), 2) as total_mrr,
    ROUND(SUM(mrr) FILTER (WHERE has_churned = FALSE), 2) as active_mrr,
    ROUND(SUM(mrr) FILTER (WHERE has_churned = TRUE), 2) as churned_mrr,
    ROUND(AVG(mrr), 2) as avg_mrr,
    ROUND(SUM(clv_lost), 2) as total_revenue_lost,
    COUNT(*) FILTER (WHERE health_category IN ('Critical', 'Churning')) as high_risk_count,
    ROUND(SUM(mrr) FILTER (WHERE health_category IN ('Critical', 'Churning')), 2) as high_risk_mrr
FROM fact_customer_metrics;




-- VIEW 2: Churn Analysis by Dimension

CREATE OR REPLACE VIEW vw_churn_by_dimension AS
-- By Subscription Type
SELECT 
    'Subscription Type' as dimension,
    s.subscription_type as segment,
    COUNT(*) as customers,
    SUM(CASE WHEN m.has_churned THEN 1 ELSE 0 END) as churned,
    ROUND(AVG(CASE WHEN m.has_churned THEN 1 ELSE 0 END) * 100, 2) as churn_rate_pct,
    ROUND(SUM(m.mrr), 2) as total_mrr
FROM fact_customer_metrics m
JOIN dim_subscription s ON m.customer_id = s.customer_id
GROUP BY s.subscription_type

UNION ALL

-- By Contract Length
SELECT 
    'Contract Length' as dimension,
    s.contract_length as segment,
    COUNT(*),
    SUM(CASE WHEN m.has_churned THEN 1 ELSE 0 END),
    ROUND(AVG(CASE WHEN m.has_churned THEN 1 ELSE 0 END) * 100, 2),
    ROUND(SUM(m.mrr), 2)
FROM fact_customer_metrics m
JOIN dim_subscription s ON m.customer_id = s.customer_id
GROUP BY s.contract_length

UNION ALL

-- By Health Category
SELECT 
    'Health Category' as dimension,
    health_category as segment,
    COUNT(*),
    SUM(CASE WHEN has_churned THEN 1 ELSE 0 END),
    ROUND(AVG(CASE WHEN has_churned THEN 1 ELSE 0 END) * 100, 2),
    ROUND(SUM(mrr), 2)
FROM fact_customer_metrics
GROUP BY health_category

UNION ALL

-- By Engagement Tier
SELECT 
    'Engagement Tier' as dimension,
    engagement_tier as segment,
    COUNT(*),
    SUM(CASE WHEN has_churned THEN 1 ELSE 0 END),
    ROUND(AVG(CASE WHEN has_churned THEN 1 ELSE 0 END) * 100, 2),
    ROUND(SUM(mrr), 2)
FROM fact_customer_metrics
GROUP BY engagement_tier

UNION ALL

-- By Cohort
SELECT 
    'Cohort' as dimension,
    cohort as segment,
    COUNT(*),
    SUM(CASE WHEN has_churned THEN 1 ELSE 0 END),
    ROUND(AVG(CASE WHEN has_churned THEN 1 ELSE 0 END) * 100, 2),
    ROUND(SUM(mrr), 2)
FROM fact_customer_metrics
GROUP BY cohort;



-- VIEW 3: Customer Detail (for drill-down)

CREATE OR REPLACE VIEW vw_customer_detail AS
SELECT 
    m.customer_id,
    c.age,
    c.gender,
    s.subscription_type,
    s.contract_length,
    m.tenure_months,
    m.mrr,
    m.clv_actual,
    m.health_score,
    m.health_category,
    m.engagement_tier,
    m.payment_risk,
    m.cohort,
    m.has_churned,
    m.usage_frequency,
    m.support_calls,
    m.payment_delay_count,
    m.last_interaction_days
FROM fact_customer_metrics m
JOIN dim_customer c ON m.customer_id = c.customer_id
JOIN dim_subscription s ON m.customer_id = s.customer_id;



-- VIEW 4: Revenue Waterfall

CREATE OR REPLACE VIEW vw_revenue_waterfall AS
SELECT 
    'Total MRR' as category,
    1 as sort_order,
    ROUND(SUM(mrr), 2) as amount
FROM fact_customer_metrics

UNION ALL

SELECT 
    'Active MRR' as category,
    2 as sort_order,
    ROUND(SUM(mrr) FILTER (WHERE has_churned = FALSE), 2)
FROM fact_customer_metrics

UNION ALL

SELECT 
    'Churned MRR' as category,
    3 as sort_order,
    ROUND(SUM(mrr) FILTER (WHERE has_churned = TRUE), 2)
FROM fact_customer_metrics

UNION ALL

SELECT 
    'Revenue Lost (Potential)' as category,
    4 as sort_order,
    ROUND(SUM(clv_lost), 2)
FROM fact_customer_metrics

ORDER BY sort_order;



-- VIEW 5: Cohort Retention Curve

CREATE OR REPLACE VIEW vw_cohort_retention AS
SELECT 
    cohort,
    COUNT(*) as total_customers,
    SUM(CASE WHEN has_churned = FALSE THEN 1 ELSE 0 END) as retained_customers,
    ROUND(AVG(CASE WHEN has_churned = FALSE THEN 1 ELSE 0 END) * 100, 2) as retention_rate_pct,
    CASE cohort
        WHEN 'New (0-3m)' THEN 1
        WHEN 'Growing (4-12m)' THEN 2
        WHEN 'Mature (13-24m)' THEN 3
        WHEN 'Veteran (25m+)' THEN 4
    END as sort_order
FROM fact_customer_metrics
GROUP BY cohort
ORDER BY sort_order;



-- VIEW 6: At-Risk Customer Action List

CREATE OR REPLACE VIEW vw_at_risk_customers AS
SELECT 
    m.customer_id,
    c.age,
    c.gender,
    s.subscription_type,
    s.contract_length,
    m.mrr,
    m.tenure_months,
    m.health_score,
    m.health_category,
    m.payment_delay_count,
    m.support_calls,
    m.engagement_tier,
    CASE 
        WHEN m.mrr >= (SELECT PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY mrr) FROM fact_customer_metrics) 
        THEN 'High Value'
        WHEN m.mrr >= (SELECT PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY mrr) FROM fact_customer_metrics)
        THEN 'Medium Value'
        ELSE 'Low Value'
    END as value_segment
FROM fact_customer_metrics m
JOIN dim_customer c ON m.customer_id = c.customer_id
JOIN dim_subscription s ON m.customer_id = s.customer_id
WHERE 
    m.has_churned = FALSE
    AND m.health_category IN ('Critical', 'Churning')
ORDER BY m.mrr DESC;
