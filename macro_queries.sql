-- GDP Ratios
SELECT
    g.geo_name,
    -- i.variable,
    case
        when i.variable = 'fiscal_monitor_gross_debt_(%_of_gdp_|_gross_debt_(%_of_gdp_|_annual' then 'debt_to_gdp_ratio'
        when i.variable = 'fiscal_monitor_revenue_(%_of_gdp_|_revenue_(%_of_gdp_|_annual' then 'rev_to_gdp_ratio'
    end as indicator,
    i.date,
    i.value,
    i.unit
FROM
    international_monetary_fund_timeseries i
    JOIN geography_index g ON i.geo_id = g.geo_id
WHERE
    STARTSWITH(i.geo_id, 'country/')
    AND geo_id <> 'country/USA'
    AND i.date > '2010-01-01'
    AND i.VARIABLE IN (
        'fiscal_monitor_gross_debt_(%_of_gdp_|_gross_debt_(%_of_gdp_|_annual',
        'fiscal_monitor_revenue_(%_of_gdp_|_revenue_(%_of_gdp_|_annual'
    );

    
-- trade balance & reserves
SELECT
    g.geo_name,
    o.date,
    o.value,
    o.variable,
    o.variable_name
FROM
    oecd_timeseries o
    JOIN geography_index g ON o.geo_id = g.geo_id
WHERE
    STARTSWITH(o.geo_id, 'country/')
    AND o.date > '2010-01-01'
    AND o.unit = 'USD'
    AND g.geo_id <> 'country/USA'
    AND g.level = 'Country'
    AND o.variable in (
        -- reserves
        'BAL_OF_PAY_N_FA_USD_EXC__Z_Q_N',
        -- Balance of payments to rest of the world: net (assets minus liabilities) from financial account in US dollars, exchange rate converted, Monthly
        -- trade balances
        'BAL_OF_PAY_B_CA_USD_EXC__Z_Q_N',
        -- Balance of payments to rest of the world: balance (revenue minus expenditure) from current account in US dollars, exchange rate converted, Monthly
        'BAL_OF_PAY_B_CA_USD_EXC__Z_Q_Y' -- Balance of payments to rest of the world: balance (revenue minus expenditure) from current account in US dollars, exchange rate converted, Monthly (Calendar and seasonally adjusted)
    );

with cpi as (
-- CPI
select
    g.geo_name,
    b.variable_name,
    b.date,
    b.value,
    b.unit
from
    BANK_FOR_INTERNATIONAL_SETTLEMENTS_TIMESERIES b
    JOIN geography_index g ON b.geo_id = g.geo_id
WHERE
    b.GEO_ID IS NOT NULL
    AND STARTSWITH(b.GEO_ID, 'country/')
    AND b.geo_id <> 'country/USA'
    AND b.UNIT = 'Percent'
    AND startswith(b.variable, 'BIS,WS_LONG_CPI,1.0,M')
    AND DATE > '2010-01-01'
),

rates as (
-- interest rates
select
    geo_name,
    b.variable_name,
    b.date,
    b.value, 
    b.unit
from
    BANK_FOR_INTERNATIONAL_SETTLEMENTS_TIMESERIES b
    JOIN geography_index g ON b.geo_id = g.geo_id
WHERE
    b.GEO_ID IS NOT NULL
    AND STARTSWITH(b.GEO_ID, 'country/')
    AND b.geo_id <> 'country/USA'
    AND UNIT = 'Percent'
    AND startswith(variable, 'BIS,WS_CBPOL,1.0,M')
    AND DATE > '2010-01-01'
)

select 
    r.geo_name as country,
    r.date,
    r.value as rate_pct,
    c.value as inflation_pct,
    r.value - c.value as real_interest_rate
    
from rates r
join cpi c on r.geo_name = c.geo_name AND r.date = c.date
;

-- GDP Growth
SELECT  
    geo_name,
    o.variable_name,
    o.date,
    o.value,
    o.unit
FROM OECD_TIMESERIES o
JOIN geography_index g ON o.geo_id = g.geo_id
WHERE variable = 'CLI_N_RS__Z_IX__Z_IX_Q_Y'
AND g.geo_id IS NOT NULL
    AND STARTSWITH(g.geo_id, 'country/')
    AND g.geo_id <> 'country/USA'
    AND o.date > '2010-01-01'
    ORDER BY geo_name, o.date
;