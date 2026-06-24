-- =============================================================================
-- seed-qa-cotacao-v2.sql
-- Espelha o fluxo real de cotacao.youse.com.br/seguro-auto
-- =============================================================================

\echo '▶ Seed monolithic_qa (fluxo real Youse Seguro Auto)...'

CREATE DATABASE monolithic_qa;
\c monolithic_qa

-- Leads = primeira etapa do fluxo (nome + email + telefone)
CREATE TABLE leads (
    id            SERIAL PRIMARY KEY,
    lead_uuid     VARCHAR(40) UNIQUE NOT NULL,
    name          VARCHAR(200) NOT NULL,
    email         VARCHAR(200) NOT NULL,
    phone         VARCHAR(20),
    insurance_type VARCHAR(30) DEFAULT 'auto',
    source        VARCHAR(50) DEFAULT 'home',
    created_at    TIMESTAMP DEFAULT NOW()
);

-- Vehicles = dados do carro (etapa 2)
CREATE TABLE vehicles (
    id            SERIAL PRIMARY KEY,
    lead_id       INT REFERENCES leads(id) ON DELETE CASCADE,
    license_plate VARCHAR(8),
    brand         VARCHAR(50),
    model         VARCHAR(100),
    year          INT,
    fipe_value    DECIMAL(10,2),
    created_at    TIMESTAMP DEFAULT NOW()
);

-- Quotes = cotacao final com premio
CREATE TABLE quotes (
    id                SERIAL PRIMARY KEY,
    quote_number      VARCHAR(20) UNIQUE NOT NULL,
    lead_id           INT REFERENCES leads(id) ON DELETE CASCADE,
    vehicle_id        INT REFERENCES vehicles(id),
    coverage_type     VARCHAR(30),
    monthly_premium   DECIMAL(10,2),
    annual_premium    DECIMAL(10,2),
    status            VARCHAR(20) DEFAULT 'draft',
    email_sent_at     TIMESTAMP,
    created_at        TIMESTAMP DEFAULT NOW()
);

-- Massa de QA — leads existentes
INSERT INTO leads (lead_uuid, name, email, phone) VALUES
    ('lead-qa-001', 'Joao da Silva',   'joao.qa@youse.test',   '(11) 99999-0001'),
    ('lead-qa-002', 'Maria Souza',     'maria.qa@youse.test',  '(11) 99999-0002'),
    ('lead-qa-003', 'Pedro Oliveira',  'pedro.qa@youse.test',  '(11) 99999-0003');

INSERT INTO vehicles (lead_id, license_plate, brand, model, year, fipe_value) VALUES
    (1, 'ABC1D23', 'Volkswagen', 'Gol 1.0',       2022, 65000.00),
    (2, 'XYZ4E56', 'Honda',      'Civic Touring', 2023, 185000.00),
    (3, 'BRA2E19', 'Toyota',     'Corolla XEi',   2024, 165000.00);

INSERT INTO quotes (quote_number, lead_id, vehicle_id, coverage_type, monthly_premium, annual_premium, status) VALUES
    ('YSE-QA-0001', 1, 1, 'completo', 189.90, 2278.80, 'completed'),
    ('YSE-QA-0002', 2, 2, 'completo', 342.50, 4110.00, 'completed'),
    ('YSE-QA-0003', 3, 3, 'premium',  398.00, 4776.00, 'pending');

CREATE INDEX idx_leads_email ON leads(email);
CREATE INDEX idx_vehicles_lead ON vehicles(lead_id);
CREATE INDEX idx_quotes_lead ON quotes(lead_id);

GRANT USAGE ON SCHEMA public TO youse;
GRANT ALL ON ALL TABLES IN SCHEMA public TO youse;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO youse;

\echo '✓ Seed completo: 3 leads, 3 veiculos, 3 cotacoes'
