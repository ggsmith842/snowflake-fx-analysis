-- This is your Cortex Project.
-----------------------------------------------------------
-- SETUP
-----------------------------------------------------------
use role SYSADMIN;
use warehouse COMPUTE_WH;
use database FX_INVESTMENT;
use schema PUBLIC;

-- create fx symbol variable 
SET currency_id = 'GBP';

-- Inspect the first 10 rows of your training data. This is the data we'll use to create your model.
SELECT
    to_timestamp_ntz(DATE) as DATE_v1,
    VALUE,
    QUOTE_CURRENCY_ID
FROM FINANCE__ECONOMICS.CYBERSYN.FX_RATES_TIMESERIES
-- apply filters needed
WHERE quote_currency_id = $currency_id AND BASE_CURRENCY_ID='USD'
AND DATE > '2000-01-01';

-- Prepare your training data. Timestamp_ntz is a required format. Also, only include select columns.
CREATE OR REPLACE VIEW FX_INVESTMENT.PUBLIC.FX_RATES_TIMESERIES_v1 AS SELECT
    to_timestamp_ntz(DATE) as DATE_v1,
    VALUE,
    QUOTE_CURRENCY_ID
FROM FINANCE__ECONOMICS.CYBERSYN.FX_RATES_TIMESERIES
WHERE quote_currency_id = $currency_id AND BASE_CURRENCY_ID='USD';


-----------------------------------------------------------
-- CREATE PREDICTIONS
-----------------------------------------------------------
-- Create your model.
CREATE OR REPLACE SNOWFLAKE.ML.FORECAST my_model(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'FX_RATES_TIMESERIES_v1'),
    SERIES_COLNAME => 'QUOTE_CURRENCY_ID',
    TIMESTAMP_COLNAME => 'DATE_v1',
    TARGET_COLNAME => 'VALUE',
    CONFIG_OBJECT => { 'ON_ERROR': 'SKIP' }
);

-- Generate predictions and store the results to a table.
BEGIN
    -- This is the step that creates your predictions.
    CALL my_model!FORECAST(
        FORECASTING_PERIODS => 365,
        -- Here we set your prediction interval.
        CONFIG_OBJECT => {'prediction_interval': 0.95}
    );
    -- These steps store your predictions to a table.
    LET x := SQLID;
    CREATE OR REPLACE TABLE My_forecasts_2025_03_26 AS SELECT * FROM TABLE(RESULT_SCAN(:x));
END;

-- Calculate predicted return 
SELECT ts, 
    round(((forecast  - (select value 
                    FROM FINANCE__ECONOMICS.CYBERSYN.FX_RATES_TIMESERIES
                    WHERE quote_currency_id = $currency_id AND BASE_CURRENCY_ID='USD'
                    ORDER BY DATE desc limit 1)) / forecast) * 100,3) AS percent_return 
FROM My_forecasts_2025_03_26
ORDER BY ts DESC
limit 1;


-- Union your predictions with your historical data, then view the results in a chart.
SELECT QUOTE_CURRENCY_ID, DATE, VALUE AS actual, NULL AS forecast, NULL AS lower_bound, NULL AS upper_bound
    FROM FINANCE__ECONOMICS.CYBERSYN.FX_RATES_TIMESERIES
    WHERE quote_currency_id = $currency_id AND BASE_CURRENCY_ID='USD'
    and date > '2024-01-01'
UNION ALL
SELECT replace(series, '"', '') as QUOTE_CURRENCY_ID, ts as DATE, NULL AS actual, forecast, lower_bound, upper_bound
    FROM My_forecasts_2025_03_26;

-----------------------------------------------------------
-- INSPECT RESULTS
-----------------------------------------------------------

-- Inspect the accuracy metrics of your model. 
CALL my_model!SHOW_EVALUATION_METRICS();

-- Inspect the relative importance of your features, including auto-generated features. 
CALL my_model!EXPLAIN_FEATURE_IMPORTANCE();
