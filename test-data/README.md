# Test SQLite Database for Google GenAI Toolbox

## Overview

This directory contains a test SQLite database used for testing the Google GenAI Toolbox MCP server integration with Claude.

## Database Information

**File**: `test.db`
**Type**: SQLite 3
**Location**: `~/dotfiles/test-data/test.db`

## Database Schema

### Tables

#### `users`
| Column | Type | Constraints |
|--------|------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT |
| name | TEXT | NOT NULL |
| email | TEXT | UNIQUE NOT NULL |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP |

**Sample Data**: 5 users with test email addresses

#### `posts`
| Column | Type | Constraints |
|--------|------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT |
| user_id | INTEGER | NOT NULL, FOREIGN KEY → users(id) |
| title | TEXT | NOT NULL |
| content | TEXT | - |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP |

**Sample Data**: 10 posts distributed across users

## Connection Information

### For Claude Desktop
The database is configured in `claude_desktop_config.json` with:
```json
"genai-toolbox": {
  "command": "bunx",
  "args": ["-y", "@googlegenai/genai-toolbox"],
  "env": {
    "DATABASE_URL": "sqlite:///Users/shahe/dotfiles/test-data/test.db"
  }
}
```

### For Claude Code CLI
The MCP server is added via setup script. To use it, set the DATABASE_URL environment variable:
```bash
export DATABASE_URL="sqlite:///Users/shahe/dotfiles/test-data/test.db"
```

## Example Queries to Test with Claude

Once the Google GenAI Toolbox MCP is configured, you can ask Claude:

### Basic Queries
- "Show me the schema of the test database"
- "How many users are in the database?"
- "List all users with their email addresses"
- "How many posts does each user have?"

### Advanced Queries
- "Show me all posts by users whose email contains 'example.com'"
- "Find the most active user (by post count)"
- "List all posts created in the last week"
- "Show me posts with titles containing 'Database'"

### Schema Operations
- "What tables exist in this database?"
- "Show me the structure of the posts table"
- "What are the relationships between tables?"

### Code Generation
- "Write Python code to fetch all users from the database"
- "Generate a SQL query to find users with no posts"
- "Create a function to insert a new post"

## Manual Database Access

You can also access the database directly using the SQLite CLI:

```bash
# Open the database
sqlite3 ~/dotfiles/test-data/test.db

# View all tables
.tables

# View table schema
.schema users

# Query data
SELECT * FROM users;
SELECT u.name, COUNT(p.id) as post_count
FROM users u
LEFT JOIN posts p ON u.id = p.user_id
GROUP BY u.id;

# Exit
.quit
```

## Maintenance

### Reset Database
To reset the database to its initial state, delete and recreate it:
```bash
rm ~/dotfiles/test-data/test.db
# Then re-run the database creation SQL from the setup script
```

### Add More Data
```bash
sqlite3 ~/dotfiles/test-data/test.db
INSERT INTO users (name, email) VALUES ('New User', 'newuser@example.com');
INSERT INTO posts (user_id, title, content) VALUES (6, 'New Post', 'Test content');
.quit
```

## Purpose

This test database is designed to:
1. Demonstrate Google GenAI Toolbox MCP capabilities
2. Provide a safe sandbox for testing database queries
3. Enable testing of Claude's natural language database interaction
4. Serve as a reference for database schema design

## Security Note

This is a TEST database with sample data only. Never store sensitive or production data in this database.
