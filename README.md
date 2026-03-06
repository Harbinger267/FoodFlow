# FoodFlow - Catering Inventory Management System

A comprehensive inventory management system designed for school catering departments.

## 🎯 Overview

FoodFlow is a Java Servlet-based inventory management system that helps catering departments track supplies, manage usage, record damages, and generate detailed reports. Built with MySQL database and designed for scalability.

## ✨ Features

- **User Management** - Role-based access (Admin, Department Head, Cook)
- **Inventory Tracking** - Real-time stock levels with low-stock alerts
- **Supply Management** - Track incoming supplies from vendors
- **Usage Monitoring** - Record and analyze consumption patterns
- **Damage Logging** - Track damaged items and identify patterns
- **Store Requests** - Formal requisition workflow with approval process
- **Comprehensive Reporting** - Inventory status, usage analytics, user activity
- **Audit Trail** - Complete system logging for accountability

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    FoodFlow System                          │
├─────────────────────────────────────────────────────────────┤
│  Presentation Layer                                         │
│  ├── JSP Views (Login, Dashboard, Forms, Reports)          │
│  └── Static Assets (CSS, JavaScript, Images)                │
├─────────────────────────────────────────────────────────────┤
│  Controller Layer                                           │
│  ├── AuthController    ├── ItemController                   │
│  ├── SupplyController  ├── UsageController                  │
│  ├── DamageController  ├── ReportController                 │
│  └── UserController    └── DashboardController              │
├─────────────────────────────────────────────────────────────┤
│  Service/DAO Layer                                          │
│  ├── UserDAO           ├── ItemDAO                          │
│  ├── SupplyDAO         ├── UsageDAO                         │
│  ├── DamageDAO         ├── ReportDAO                        │
│  └── DatabaseConfig                                         │
├─────────────────────────────────────────────────────────────┤
│  Database Layer (MySQL)                                     │
│  ├── roles             ├── users                            │
│  ├── categories        ├── items                            │
│  ├── store_requests    ├── request_details                  │
│  ├── stock_transactions├── damage_log                       │
│  └── system_logs                                            │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
FoodFlow/
├── database/
│   ├── schema.sql                    # Complete database schema
│   ├── sample_data.sql               # Test data
│   ├── SETUP_GUIDE.md                # Installation instructions
│   ├── QUICK_REFERENCE.md            # Query lookup guide
│   └── queries/
│       ├── items_queries.sql         # Item CRUD operations
│       ├── supply_queries.sql        # Stock-in transactions
│       ├── usage_queries.sql         # Stock-out transactions
│       ├── damage_queries.sql        # Damage tracking
│       └── report_queries.sql        # Analytics & reporting
├── src/
│   ├── main/
│   │   ├── java/com/foodflow/
│   │   │   ├── config/               # Configuration classes
│   │   │   ├── controller/           # Servlet controllers
│   │   │   ├── dao/                  # Data Access Objects
│   │   │   ├── model/                # Entity classes
│   │   │   └── util/                 # Utility classes
│   │   └── resources/
│   │       ├── static/               # CSS, JS, images
│   │       └── templates/            # JSP views
│   └── test/                         # Unit tests
├── docs/                             # Documentation
├── scripts/                          # Setup & backup scripts
├── pom.xml                           # Maven configuration
└── README.md                         # This file
```

## 🚀 Quick Start

### Prerequisites

- **Java 11+**
- **Maven 3.6+**
- **MySQL 8.0+**
- **Servlet Container** (Apache Tomcat 9+)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd FoodFlow
   ```

2. **Set up the database**
   ```bash
   mysql -u root -p < database/schema.sql
   mysql -u root -p foodflow < database/sample_data.sql
   ```

3. **Build the project**
   ```bash
   mvn clean package
   ```

4. **Deploy to Tomcat**
   ```bash
   # Copy target/foodflow.war to Tomcat webapps directory
   cp target/foodflow.war $TOMCAT_HOME/webapps/
   ```

5. **Access the application**
   ```
   http://localhost:8080/foodflow
   ```

### Default Credentials

| Role | Email | Password |
|------|-------|----------|
| Admin | admin@foodflow.com | password |
| Department Head | head@foodflow.com | password |
| Cook | cook1@foodflow.com | password |

⚠️ **Change these passwords immediately in production!**

## 📊 Database Schema

### Entity Relationships (Crow's Foot Notation)

```
ROLES (1) ──< (Many) USERS
USERS (1) ──< (Many) SYSTEM_LOGS
CATEGORIES (1) ──< (Many) ITEMS
USERS (1) ──< (Many) STORE_REQUESTS (as Requester)
USERS (1) ──< (Many) STORE_REQUESTS (as Approver)
STORE_REQUESTS (1) ──< (Many) REQUEST_DETAILS
ITEMS (1) ──< (Many) REQUEST_DETAILS
ITEMS (1) ──< (Many) STOCK_TRANSACTIONS
USERS (1) ──< (Many) STOCK_TRANSACTIONS
ITEMS (1) ──< (Many) DAMAGE_LOG
USERS (1) ──< (Many) DAMAGE_LOG
```

### Key Tables

| Table | Purpose | Key Fields |
|-------|---------|------------|
| **roles** | User role definitions | role_id (PK), role_title |
| **users** | System users | user_id (PK), user_name, email, role_id (FK) |
| **categories** | Item categories | category_id (PK), category_name |
| **items** | Inventory items | item_id (PK), item_name, current_stock, category_id (FK) |
| **store_requests** | Requisition workflow | request_id (PK), requester_id (FK), approver_id (FK) |
| **stock_transactions** | Unified transaction log | transaction_id (PK), item_id (FK), transaction_type |
| **damage_log** | Damage incidents | damage_id (PK), item_id (FK), quantity, reported_by (FK) |

## 🔧 Technology Stack

### Backend
- **Java 11** - Programming language
- **Java Servlets 4.0** - Web framework
- **JSP 2.3** - View technology
- **JSTL 1.2** - Tag library

### Database
- **MySQL 8.0** - RDBMS
- **HikariCP 4.0** - Connection pooling

### Libraries
- **BCrypt** - Password hashing
- **Gson** - JSON processing
- **SLF4J** - Logging
- **Apache Commons Lang** - Utilities

### Build Tool
- **Maven 3.6** - Dependency management & build

## 📚 Documentation

| Document | Description | Location |
|----------|-------------|----------|
| **Setup Guide** | Complete installation instructions | `database/SETUP_GUIDE.md` |
| **Quick Reference** | SQL query lookup guide | `database/QUICK_REFERENCE.md` |
| **Implementation Summary** | Technical implementation details | `database/IMPLEMENTATION_SUMMARY.md` |
| **API Documentation** | REST API specifications | `docs/api-documentation.md` |
| **Technical Docs** | System architecture & design | `docs/technical-documentation.md` |

## 🎯 Key Features Explained

### 1. Inventory Management
- Real-time stock tracking
- Automatic low-stock alerts
- Category-based organization
- Search and filter capabilities
- Status management (Available, Low Stock, Out of Stock)

### 2. Supply Chain Tracking
- Record incoming supplies
- Track supplier information
- Monitor delivery dates
- Update stock levels automatically

### 3. Usage Monitoring
- Log daily consumption
- Track usage by department/user
- Analyze consumption patterns
- Predict stockout dates

### 4. Damage Control
- Record damage incidents
- Calculate damage rates
- Identify recurring issues
- Financial impact analysis

### 5. Store Requests
- Formal requisition process
- Approval workflow
- Multi-item requests
- Status tracking (Pending, Approved, Rejected)

### 6. Comprehensive Reporting
- Current inventory status
- Stock movement summaries
- User activity reports
- Category analysis
- Trend analysis

## 🔒 Security Features

- **BCrypt password hashing** - Industry-standard password security
- **Role-based access control** - Different permissions per role
- **SQL injection prevention** - Prepared statements throughout
- **Session management** - Secure user sessions
- **Audit logging** - Complete activity trail

## 📈 Reporting Capabilities

### Inventory Reports
- Current stock levels
- Low stock alerts
- Reorder recommendations

### Transaction Reports
- Stock movement (IN/OUT/DAMAGED)
- Period summaries
- Item-wise analysis

### Activity Reports
- User performance metrics
- System audit trail
- Approval timelines

### Analytics
- Consumption trends
- Damage pattern analysis
- Category-wise insights

## 🛠️ Development

### Build Commands

```bash
# Clean build
mvn clean install

# Run tests
mvn test

# Package WAR file
mvn package

# Skip tests
mvn package -DskipTests
```

### Running Locally

```bash
# Start Tomcat with auto-reload
mvn tomcat7:run

# Or deploy to local Tomcat
mvn cargo:run
```

## 🧪 Testing

Run all tests:
```bash
mvn test
```

Test coverage reports:
```bash
mvn clean test jacoco:report
```

## 📝 License

This project is proprietary software developed for educational purposes.

## 👥 Authors

Developed for the School Catering Department Inventory Management System.

## 🤝 Contributing

This is a closed-source project. For questions or issues, contact the development team.

## 📞 Support

For technical support:
1. Check the documentation in `docs/` folder
2. Review `database/SETUP_GUIDE.md` for database issues
3. Contact the system administrator

## 🎓 Learning Resources

- [MySQL Documentation](https://dev.mysql.com/doc/)
- [Java Servlet Tutorial](https://www.baeldung.com/java-servlets)
- [Maven Getting Started](https://maven.apache.org/guides/getting-started/)
- [BCrypt Documentation](https://github.com/jeremyh/jBCrypt)

---

**Last Updated:** March 2026  
**Version:** 1.0.0