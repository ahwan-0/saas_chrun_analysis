

-- Retention Rate by Cohort (Survival Analysis)
-- BUSINESS QUESTION: "What % of customers survive at each lifecycle stage?"

WITH cohort_order AS (
    SELECT 
        cohort,
        COUNT(*) as customers,
        SUM(CASE WHEN has_churned = FALSE THEN 1 ELSE 0 END) as retained,
        ROUND(AVG(CASE WHEN has_churned = FALSE THEN 1 ELSE 0 END) * 100, 2) as retention_rate_pct,
        CASE cohort
            WHEN 'New (0-3m)' THEN 1
            WHEN 'Growing (4-12m)' THEN 2
            WHEN 'Mature (13-24m)' THEN 3
            WHEN 'Veteran (25m+)' THEN 4
        END as cohort_order
    FROM fact_customer_metrics
    GROUP BY cohort
)
SELECT 
    cohort,
    customers,
    retained,
    retention_rate_pct,
    -- Cumulative retention (what % make it to this stage)
    ROUND(
        (retained::DECIMAL / (SELECT SUM(customers) FROM cohort_order)) * 100, 
        2
    ) as pct_of_total_base
FROM cohort_order
ORDER BY cohort_order;



-- High-Value At-Risk Customers (Action List)
-- BUSINESS QUESTION: "Which specific customers should we save RIGHT NOW?"

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
    m.usage_frequency,
    m.engagement_tier,
    -- Risk score (0-100, higher = more at risk)
    ROUND(
        (100 - m.health_score) * 0.5 +  -- Health contributes 50%
        (m.payment_delay_count * 2) +    -- Each delay adds 2 points
        (m.support_calls * 1.5) +        -- Each call adds 1.5 points
        CASE 
            WHEN m.engagement_tier = 'Low' THEN 20
            WHEN m.engagement_tier = 'Medium' THEN 10
            ELSE 0
        END,
        2
    ) as composite_risk_score
FROM fact_customer_metrics m
JOIN dim_customer c ON m.customer_id = c.customer_id
JOIN dim_subscription s ON m.customer_id = s.customer_id
WHERE 
    m.has_churned = FALSE  -- Not churned yet
    AND m.mrr > (SELECT PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY mrr) FROM fact_customer_metrics)  -- Top 25% MRR
    AND m.health_category IN ('Critical', 'Churning')  -- High risk
ORDER BY composite_risk_score DESC, m.mrr DESC
LIMIT 100;



-- BUSINESS QUESTION: "Which factors are MOST predictive of churn?"

SELECT 
    'Payment Delay' as factor,
    ROUND(AVG(CASE WHEN payment_delay_count >= 3 AND has_churned = TRUE THEN 1 ELSE 0 END) * 100, 2) as churn_rate_when_true,
    ROUND(AVG(CASE WHEN payment_delay_count < 3 AND has_churned = TRUE THEN 1 ELSE 0 END) * 100, 2) as churn_rate_when_false,
    ROUND(
        AVG(CASE WHEN payment_delay_count >= 3 AND has_churned = TRUE THEN 1 ELSE 0 END) * 100 -
        AVG(CASE WHEN payment_delay_count < 3 AND has_churned = TRUE THEN 1 ELSE 0 END) * 100,
        2
    ) as churn_lift_pct
FROM fact_customer_metrics

UNION ALL

SELECT 
    'Low Engagement' as factor,
    ROUND(AVG(CASE WHEN engagement_tier = 'Low' AND has_churned = TRUE THEN 1 ELSE 0 END) * 100, 2),
    ROUND(AVG(CASE WHEN engagement_tier != 'Low' AND has_churned = TRUE THEN 1 ELSE 0 END) * 100, 2),
    ROUND(
        AVG(CASE WHEN engagement_tier = 'Low' AND has_churned = TRUE THEN 1 ELSE 0 END) * 100 -
        AVG(CASE WHEN engagement_tier != 'Low' AND has_churned = TRUE THEN 1 ELSE 0 END) * 100,
        2
    )
FROM fact_customer_metrics

UNION ALL

SELECT 
    'High Support Calls' as factor,
    ROUND(AVG(CASE WHEN support_calls >= 5 AND has_churned = TRUE THEN 1 ELSE 0 END) * 100, 2),
    ROUND(AVG(CASE WHEN support_calls < 5 AND has_churned = TRUE THEN 1 ELSE 0 END) * 100, 2),
    ROUND(
        AVG(CASE WHEN support_calls >= 5 AND has_churned = TRUE THEN 1 ELSE 0 END) * 100 -
        AVG(CASE WHEN support_calls < 5 AND has_churned = TRUE THEN 1 ELSE 0 END) * 100,
        2
    )
FROM fact_customer_metrics

ORDER BY churn_lift_pct DESC;



WITH mrr_breakdown AS (
    SELECT 
        SUM(mrr) as current_total_mrr,
        SUM(mrr) FILTER (WHERE has_churned = FALSE) as active_mrr,
        SUM(mrr) FILTER (WHERE has_churned = TRUE) as churned_mrr,
        SUM(mrr) FILTER (WHERE cohort = 'New (0-3m)' AND has_churned = FALSE) as new_customer_mrr,
        SUM(clv_lost) FILTER (WHERE has_churned = TRUE) as potential_revenue_lost
    FROM fact_customer_metrics
)
SELECT 
    'Current Total MRR' as metric,
    ROUND(current_total_mrr, 2) as value
FROM mrr_breakdown

UNION ALL

SELECT 'Active Customer MRR', ROUND(active_mrr, 2)
FROM mrr_breakdown

UNION ALL

SELECT 'Churned Customer MRR (Lost)', ROUND(churned_mrr, 2)
FROM mrr_breakdown

UNION ALL

SELECT 'New Customer MRR', ROUND(new_customer_mrr, 2)
FROM mrr_breakdown

UNION ALL

SELECT 'Potential Revenue Lost', ROUND(potential_revenue_lost, 2)
FROM mrr_breakdown;

