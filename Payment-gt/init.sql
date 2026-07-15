-- filename: init.sql

CREATE DATABASE gateway_db;
CREATE DATABASE customer_db;
CREATE DATABASE payment_db;
CREATE DATABASE fraud_db;
CREATE DATABASE bank_connector_db;
CREATE DATABASE ledger_db;

GRANT ALL PRIVILEGES ON DATABASE gateway_db TO payments;
GRANT ALL PRIVILEGES ON DATABASE customer_db TO payments;
GRANT ALL PRIVILEGES ON DATABASE payment_db TO payments;
GRANT ALL PRIVILEGES ON DATABASE fraud_db TO payments;
GRANT ALL PRIVILEGES ON DATABASE bank_connector_db TO payments;
GRANT ALL PRIVILEGES ON DATABASE ledger_db TO payments;
