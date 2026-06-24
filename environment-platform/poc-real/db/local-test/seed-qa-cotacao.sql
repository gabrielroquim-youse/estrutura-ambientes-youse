-- =============================================================================
-- seed-qa-cotacao.sql
--
-- Simula a parte de COTAÇÃO AUTO do QA da Youse.
-- Tabelas espelham campos reais encontrados em youse-seguradora/archived-repos
-- (salesforce-customization/src/classes/QuoteBO.cls):
--   - vehicle.license_plate, vehicle.year, vehicle.price
--   - cliente: cpf, nome
--   - cotação: combo de coberturas, prêmio calculado
-- =============================================================================

\echo '▶ Criando banco simulando o QA da Youse (slice: cotação auto)...'

CREATE DATABASE monolithic_qa;
\c monolithic_qa

-- ---------------------------------------------------------------------------
-- Tabela: customers (clientes que ja cotaram)
-- ---------------------------------------------------------------------------
CREATE TABLE customers (
    id          SERIAL PRIMARY KEY,
    cpf         VARCHAR(14) UNIQUE NOT NULL,
    name        VARCHAR(200) NOT NULL,
    email       VARCHAR(200),
    phone       VARCHAR(20),
    created_at  TIMESTAMP DEFAULT NOW()
);

INSERT INTO customers (cpf, name, email, phone) VALUES
    ('111.111.111-11', 'Joao da Silva',     'joao.qa@youse.test',     '(11) 99999-0001'),
    ('222.222.222-22', 'Maria Souza',        'maria.qa@youse.test',    '(11) 99999-0002'),
    ('333.333.333-33', 'Pedro Oliveira',     'pedro.qa@youse.test',    '(11) 99999-0003'),
    ('444.444.444-44', 'Ana Costa',          'ana.qa@youse.test',      '(11) 99999-0004'),
    ('555.555.555-55', 'Carlos Pereira',     'carlos.qa@youse.test',   '(11) 99999-0005');

-- ---------------------------------------------------------------------------
-- Tabela: vehicles (veiculos com placa)
-- ---------------------------------------------------------------------------
CREATE TABLE vehicles (
    id              SERIAL PRIMARY KEY,
    customer_id     INT REFERENCES customers(id),
    license_plate   VARCHAR(8) UNIQUE NOT NULL,
    brand           VARCHAR(50),
    model           VARCHAR(100),
    year            INT,
    fipe_value      DECIMAL(10,2),
    created_at      TIMESTAMP DEFAULT NOW()
);

INSERT INTO vehicles (customer_id, license_plate, brand, model, year, fipe_value) VALUES
    (1, 'ABC1D23', 'Volkswagen', 'Gol 1.0',          2022, 65000.00),
    (2, 'XYZ4E56', 'Honda',      'Civic Touring',    2023, 185000.00),
    (3, 'BRA2E19', 'Toyota',     'Corolla XEi',      2024, 165000.00),
    (4, 'YOU5E99', 'Fiat',       'Argo 1.3',         2023, 78000.00),
    (5, 'QA00001', 'Hyundai',    'HB20 Comfort',     2022, 72000.00);

-- ---------------------------------------------------------------------------
-- Tabela: quotes (cotacoes — slice principal da feature YOU-123)
-- Espelha estrutura encontrada em QuoteBO.cls
-- ---------------------------------------------------------------------------
CREATE TABLE quotes (
    id                  SERIAL PRIMARY KEY,
    quote_number        VARCHAR(20) UNIQUE NOT NULL,
    customer_id         INT REFERENCES customers(id),
    vehicle_id          INT REFERENCES vehicles(id),
    coverage_type       VARCHAR(30),
    monthly_premium     DECIMAL(10,2),
    annual_premium      DECIMAL(10,2),
    status              VARCHAR(20) DEFAULT 'draft',
    created_at          TIMESTAMP DEFAULT NOW()
);

INSERT INTO quotes (quote_number, customer_id, vehicle_id, coverage_type, monthly_premium, annual_premium, status) VALUES
    ('YSE-2026-0001', 1, 1, 'completo',  189.90, 2278.80, 'completed'),
    ('YSE-2026-0002', 2, 2, 'completo',  342.50, 4110.00, 'completed'),
    ('YSE-2026-0003', 3, 3, 'completo',  298.00, 3576.00, 'pending'),
    ('YSE-2026-0004', 4, 4, 'basico',    132.40, 1588.80, 'completed');

-- ---------------------------------------------------------------------------
-- Indices
-- ---------------------------------------------------------------------------
CREATE INDEX idx_customers_cpf       ON customers(cpf);
CREATE INDEX idx_vehicles_plate      ON vehicles(license_plate);
CREATE INDEX idx_quotes_customer     ON quotes(customer_id);
CREATE INDEX idx_quotes_vehicle      ON quotes(vehicle_id);

-- ---------------------------------------------------------------------------
-- Permissoes para PostgREST conseguir ler/escrever via API anon
-- ---------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO youse;
GRANT ALL ON ALL TABLES IN SCHEMA public TO youse;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO youse;

\echo '✓ Banco monolithic_qa criado'
\echo '  5 clientes, 5 veiculos, 4 cotacoes'
\echo '  Pronto para ser clonado em preview_you_123'
