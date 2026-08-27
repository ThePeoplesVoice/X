-- Nexus unified entity schema.
-- SQLite is the source of truth; enable foreign-key enforcement per connection.
PRAGMA foreign_keys = ON;

CREATE TABLE clients (
  id TEXT PRIMARY KEY,
  abn TEXT UNIQUE,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  address TEXT,
  website TEXT,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive', 'archived')),
  notes TEXT,
  createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deletedAt TEXT
);

CREATE TABLE projects (
  id TEXT PRIMARY KEY,
  clientId TEXT NOT NULL REFERENCES clients(id),
  name TEXT NOT NULL,
  description TEXT,
  scope TEXT CHECK (scope IN ('one-off', 'recurring', 'retainer')),
  status TEXT NOT NULL DEFAULT 'quoted'
    CHECK (status IN ('quoted', 'active', 'on-hold', 'completed', 'cancelled')),
  estimatedValue NUMERIC CHECK (estimatedValue >= 0),
  actualValue NUMERIC CHECK (actualValue >= 0),
  startDate TEXT,
  targetDate TEXT,
  completedDate TEXT,
  priority TEXT CHECK (priority IN ('low', 'medium', 'high')),
  location TEXT,
  createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (targetDate IS NULL OR startDate IS NULL OR targetDate >= startDate),
  CHECK (completedDate IS NULL OR startDate IS NULL OR completedDate >= startDate)
);

CREATE TABLE jobs (
  id TEXT PRIMARY KEY,
  clientId TEXT NOT NULL REFERENCES clients(id),
  projectId TEXT REFERENCES projects(id),
  name TEXT NOT NULL,
  description TEXT,
  type TEXT,
  status TEXT NOT NULL DEFAULT 'quoted'
    CHECK (status IN ('quoted', 'scheduled', 'in-progress', 'completed', 'invoiced')),
  ratePerHour NUMERIC CHECK (ratePerHour >= 0),
  estimatedHours NUMERIC CHECK (estimatedHours >= 0),
  estimatedValue NUMERIC CHECK (estimatedValue >= 0),
  actualHours NUMERIC CHECK (actualHours >= 0),
  actualCost NUMERIC CHECK (actualCost >= 0),
  actualValue NUMERIC CHECK (actualValue >= 0),
  quotedDate TEXT,
  scheduledDate TEXT,
  startDate TEXT,
  completedDate TEXT,
  invoicedDate TEXT,
  materialsUsed TEXT,
  materialsCost NUMERIC CHECK (materialsCost >= 0),
  notes TEXT,
  createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (completedDate IS NULL OR startDate IS NULL OR completedDate >= startDate),
  CHECK (invoicedDate IS NULL OR status IN ('completed', 'invoiced')),
  CHECK (status NOT IN ('invoiced') OR invoicedDate IS NOT NULL)
);

CREATE TABLE invoices (
  id TEXT PRIMARY KEY,
  clientId TEXT NOT NULL REFERENCES clients(id),
  invoiceNumber TEXT UNIQUE,
  totalAmount NUMERIC NOT NULL DEFAULT 0 CHECK (totalAmount >= 0),
  taxAmount NUMERIC NOT NULL DEFAULT 0 CHECK (taxAmount >= 0),
  netAmount NUMERIC NOT NULL DEFAULT 0 CHECK (netAmount >= 0),
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'sent', 'viewed', 'partially-paid', 'paid', 'overdue', 'cancelled')),
  issuedDate TEXT,
  dueDate TEXT,
  paidDate TEXT,
  amountPaid NUMERIC NOT NULL DEFAULT 0 CHECK (amountPaid >= 0 AND amountPaid <= netAmount),
  outstandingAmount NUMERIC NOT NULL DEFAULT 0 CHECK (outstandingAmount >= 0),
  notes TEXT,
  createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (dueDate IS NULL OR issuedDate IS NULL OR dueDate >= issuedDate),
  CHECK (paidDate IS NOT NULL OR status != 'paid'),
  CHECK (status != 'paid' OR amountPaid = netAmount),
  CHECK (outstandingAmount = netAmount - amountPaid)
);

CREATE TABLE invoice_line_items (
  id TEXT PRIMARY KEY,
  invoiceId TEXT NOT NULL REFERENCES invoices(id),
  jobId TEXT REFERENCES jobs(id),
  description TEXT NOT NULL,
  quantity NUMERIC NOT NULL DEFAULT 1 CHECK (quantity >= 0),
  unitPrice NUMERIC NOT NULL DEFAULT 0 CHECK (unitPrice >= 0),
  lineTotal NUMERIC NOT NULL DEFAULT 0 CHECK (lineTotal >= 0),
  createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (lineTotal = quantity * unitPrice)
);

CREATE TABLE payments (
  id TEXT PRIMARY KEY,
  invoiceId TEXT NOT NULL REFERENCES invoices(id),
  clientId TEXT NOT NULL REFERENCES clients(id),
  amount NUMERIC NOT NULL CHECK (amount > 0),
  method TEXT CHECK (method IN ('bank-transfer', 'cash', 'cheque', 'card', 'eftpos')),
  reference TEXT,
  receivedDate TEXT NOT NULL,
  depositedDate TEXT,
  notes TEXT,
  createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (depositedDate IS NULL OR depositedDate >= receivedDate)
);

CREATE TABLE financial_summary (
  id TEXT PRIMARY KEY,
  period TEXT NOT NULL UNIQUE,
  invoicedAmount NUMERIC NOT NULL DEFAULT 0,
  paidAmount NUMERIC NOT NULL DEFAULT 0,
  outstandingAmount NUMERIC NOT NULL DEFAULT 0,
  expensesAmount NUMERIC NOT NULL DEFAULT 0,
  netCashFlow NUMERIC NOT NULL DEFAULT 0,
  collectionRate NUMERIC,
  averageDaysToPayment INTEGER,
  lastUpdated TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE trading_accounts (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  accountType TEXT CHECK (accountType IN ('spot', 'futures', 'margin', 'options')),
  apiKey TEXT,
  initialBalance NUMERIC CHECK (initialBalance >= 0),
  currentBalance NUMERIC CHECK (currentBalance >= 0),
  currentEquity NUMERIC CHECK (currentEquity >= 0),
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'paused', 'closed')),
  createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE positions (
  id TEXT PRIMARY KEY,
  assetTicker TEXT NOT NULL,
  direction TEXT NOT NULL CHECK (direction IN ('long', 'short')),
  entrySignalId TEXT,
  entryPrice NUMERIC NOT NULL CHECK (entryPrice > 0),
  entrySize NUMERIC NOT NULL CHECK (entrySize > 0),
  entryTime TEXT NOT NULL,
  entryFeeAmount NUMERIC CHECK (entryFeeAmount >= 0),
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed', 'abandoned')),
  currentPrice NUMERIC CHECK (currentPrice >= 0),
  currentValue NUMERIC,
  stopLoss NUMERIC CHECK (stopLoss > 0),
  takeProfit NUMERIC CHECK (takeProfit > 0),
  trailingStopPct NUMERIC CHECK (trailingStopPct >= 0),
  stopModifiedCount INTEGER NOT NULL DEFAULT 0 CHECK (stopModifiedCount >= 0),
  exitSignalId TEXT,
  exitPrice NUMERIC CHECK (exitPrice > 0),
  exitTime TEXT,
  exitReason TEXT CHECK (exitReason IN ('sl-hit', 'tp-hit', 'signal', 'manual', 'expired')),
  exitFeeAmount NUMERIC CHECK (exitFeeAmount >= 0),
  realizedPnL NUMERIC,
  realizedPnLPct NUMERIC,
  accountId TEXT REFERENCES trading_accounts(id),
  notes TEXT,
  createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (exitPrice IS NULL AND exitTime IS NULL OR exitPrice IS NOT NULL AND exitTime IS NOT NULL),
  CHECK (status != 'closed' OR realizedPnL IS NOT NULL),
  CHECK (direction != 'long' OR stopLoss IS NULL OR takeProfit IS NULL OR stopLoss < entryPrice AND entryPrice < takeProfit),
  CHECK (direction != 'short' OR stopLoss IS NULL OR takeProfit IS NULL OR takeProfit < entryPrice AND entryPrice < stopLoss)
);

CREATE TABLE signals (
  id TEXT PRIMARY KEY,
  botName TEXT NOT NULL,
  assetTicker TEXT NOT NULL,
  signalType TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  indicators TEXT,
  confidence NUMERIC CHECK (confidence >= 0 AND confidence <= 100),
  reasoning TEXT,
  marketCondition TEXT CHECK (marketCondition IN ('trending-up', 'trending-down', 'ranging', 'volatile')),
  marketVIX NUMERIC CHECK (marketVIX >= 0),
  status TEXT NOT NULL DEFAULT 'pending-review'
    CHECK (status IN ('pending-review', 'executed', 'rejected', 'partial-fill')),
  associatedPositionId TEXT REFERENCES positions(id),
  createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE equity_snapshots (
  id TEXT PRIMARY KEY,
  accountId TEXT NOT NULL REFERENCES trading_accounts(id),
  timestamp TEXT NOT NULL,
  balance NUMERIC,
  equity NUMERIC,
  freeMargin NUMERIC,
  usedMargin NUMERIC,
  drawdown NUMERIC CHECK (drawdown >= 0),
  openPositionsCount INTEGER CHECK (openPositionsCount >= 0),
  openPositionsPnL NUMERIC,
  createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE trading_performance (
  id TEXT PRIMARY KEY,
  accountId TEXT NOT NULL REFERENCES trading_accounts(id),
  period TEXT NOT NULL,
  tradesCount INTEGER NOT NULL DEFAULT 0 CHECK (tradesCount >= 0),
  winnersCount INTEGER NOT NULL DEFAULT 0 CHECK (winnersCount >= 0),
  losersCount INTEGER NOT NULL DEFAULT 0 CHECK (losersCount >= 0),
  breakEvenCount INTEGER NOT NULL DEFAULT 0 CHECK (breakEvenCount >= 0),
  totalRealizedPnL NUMERIC NOT NULL DEFAULT 0,
  largestWin NUMERIC,
  largestLoss NUMERIC,
  averageWin NUMERIC,
  averageLoss NUMERIC,
  winRate NUMERIC,
  profitFactor NUMERIC,
  sharpeRatio NUMERIC,
  maxDrawdown NUMERIC,
  averageHoldTime INTEGER,
  returnPct NUMERIC,
  lastUpdated TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (accountId, period),
  CHECK (winnersCount + losersCount + breakEvenCount <= tradesCount)
);

CREATE TABLE audit_log (
  id TEXT PRIMARY KEY,
  entityType TEXT NOT NULL,
  entityId TEXT NOT NULL,
  action TEXT NOT NULL,
  beforeState TEXT,
  afterState TEXT,
  changedFields TEXT,
  reason TEXT,
  correlatedEvents TEXT,
  timestamp TEXT NOT NULL
);

CREATE TABLE events (
  id TEXT PRIMARY KEY,
  eventType TEXT,
  entityId TEXT,
  timestamp TEXT NOT NULL,
  category TEXT CHECK (category IN ('business', 'market')),
  impact TEXT CHECK (impact IN ('positive', 'negative', 'neutral')),
  metadata TEXT
);

CREATE INDEX idx_clients_status ON clients(status);
CREATE INDEX idx_jobs_status ON jobs(status);
CREATE INDEX idx_invoices_clientid_status ON invoices(clientId, status);
CREATE INDEX idx_invoices_duedate ON invoices(dueDate) WHERE status != 'paid';
CREATE INDEX idx_payments_invoiceid ON payments(invoiceId);
CREATE INDEX idx_signals_timestamp ON signals(timestamp);
CREATE INDEX idx_signals_bot_ticker ON signals(botName, assetTicker);
CREATE INDEX idx_positions_status ON positions(status);
CREATE INDEX idx_positions_ticker ON positions(assetTicker);
CREATE INDEX idx_equity_snapshots_timestamp ON equity_snapshots(accountId, timestamp);
CREATE INDEX idx_audit_entity ON audit_log(entityType, entityId, timestamp);
CREATE INDEX idx_events_timestamp_category ON events(timestamp, category);
