-- =============================================================================
-- seed-qa-simulado.sql
--
-- Simula o banco de QA da Youse com dados de teste mínimos.
-- Roda automaticamente no primeiro start do container postgres-qa-simulado.
--
-- Tabelas: users, policies, orders — refletindo um domínio simplificado.
-- =============================================================================

\echo '▶ Criando banco simulando QA da Youse...'

-- Cria o banco "monolithic_qa" (mesmo nome do RDS real da Youse)
CREATE DATABASE monolithic_qa;

\c monolithic_qa

-- ---------------------------------------------------------------------------
-- Tabela: users (massa de dados de QA)
-- ---------------------------------------------------------------------------
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    cpf VARCHAR(14) UNIQUE NOT NULL,
    name VARCHAR(200) NOT NULL,
    email VARCHAR(200) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO users (cpf, name, email) VALUES
    ('111.111.111-11', 'Joao da Silva',      'joao.qa@youse.test'),
    ('222.222.222-22', 'Maria Souza',         'maria.qa@youse.test'),
    ('333.333.333-33', 'Pedro Oliveira',      'pedro.qa@youse.test'),
    ('444.444.444-44', 'Ana Costa',           'ana.qa@youse.test'),
    ('555.555.555-55', 'Carlos Pereira',      'carlos.qa@youse.test');

-- ---------------------------------------------------------------------------
-- Tabela: policies (apolices de teste)
-- ---------------------------------------------------------------------------
CREATE TABLE policies (
    id SERIAL PRIMARY KEY,
    policy_number VARCHAR(50) UNIQUE NOT NULL,
    user_id INT REFERENCES users(id),
    product VARCHAR(50) NOT NULL,
    status VARCHAR(20) DEFAULT 'active',
    premium DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO policies (policy_number, user_id, product, premium) VALUES
    ('YOU-0001', 1, 'auto',         1200.00),
    ('YOU-0002', 2, 'auto',         1850.00),
    ('YOU-0003', 3, 'residencial',   650.00),
    ('YOU-0004', 4, 'auto',         2100.00),
    ('YOU-0005', 5, 'vida',          480.00);

-- ---------------------------------------------------------------------------
-- Tabela: orders (cotacoes/pedidos)
-- ---------------------------------------------------------------------------
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id),
    status VARCHAR(20) DEFAULT 'pending',
    total DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO orders (user_id, status, total) VALUES
    (1, 'completed',  1200.00),
    (2, 'completed',  1850.00),
    (3, 'pending',     650.00),
    (4, 'completed',  2100.00);

-- ---------------------------------------------------------------------------
-- Indices basicos
-- ---------------------------------------------------------------------------
CREATE INDEX idx_users_cpf ON users(cpf);
CREATE INDEX idx_policies_user ON policies(user_id);
CREATE INDEX idx_orders_user ON orders(user_id);

\echo '✓ Banco monolithic_qa criado com 5 users, 5 policies, 4 orders'
