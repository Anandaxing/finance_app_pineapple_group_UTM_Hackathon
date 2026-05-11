# Digital_finance_app

Framework             : Flutter
Programming Language  : Dart
Database              : Turso
AI chat-bot           : Gemini AI BOT
Emulator              : IOS


Database initialization as follows : 

CREATE TABLE user_identity (
  user_id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_name VARCHAR(40),
  user_email VARCHAR(40),
  password VARCHAR(255),
  balance REAL DEFAULT 0.0,
  monthly_max_spending REAL DEFAULT 0.0,
  daily_max_spending REAL DEFAULT 0.0,
  daily_balance REAL DEFAULT 0.0,
  otp TEXT,
  otp_expiry INTEGER,
  is_verified INTEGER DEFAULT 0,
  last_automated_date TEXT DEFAULT NULL,
  points INTEGER DEFAULT 0.0.,
  last_automated_date TEXT DEFAULT NULL
);

CREATE TABLE users_transactions (
  transaction_id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_email VARCHAR(40),
  transaction_amount DECIMAL(6,2),
  time_record DATE,
  category VARCHAR(40),
  transaction_type VARCHAR(3)
);

CREATE TABLE users_plannings (
  plan_id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_email VARCHAR(40),
  to_save DECIMAL(6,2),
  time_record DATE,
  category VARCHAR(40)
);
  
CREATE TABLE user_notes (
  note_id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_email TEXT NOT NULL,
  title TEXT NOT NULL,
  content TEXT,
  created_at DATE,
  updated_at DATE
);
