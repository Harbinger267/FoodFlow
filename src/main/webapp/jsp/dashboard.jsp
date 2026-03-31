<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*, java.text.SimpleDateFormat" %>
<%--
  ============================================================
  InvenTrack Pro — Server-Side Dashboard (dashboard.jsp)
  
  Demonstrates server-side rendering of inventory data.
  In production, Java beans / service layer would populate these values.
  ============================================================
--%>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>Invetory — Server Dashboard</title>
  <link href="https://fonts.googleapis.com/css2?family=Exo+2:wght@300;400;600;700;900&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet"/>
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet"/>
  <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css" rel="stylesheet"/>
  <link rel="stylesheet" href="../css/style.css"/>
  <link rel="stylesheet" href="../css/animations.css"/>
</head>
<body>
<%
  // ---- Simulate server-side data retrieval ----
  // In production, inject via:
  //   InventoryService svc = (InventoryService) request.getAttribute("inventoryService");
  //   List<Item> items = svc.getAllItems();
  // For this demo, we simulate with static values.

  SimpleDateFormat dateFormat = new SimpleDateFormat("EEE, dd MMM yyyy");
  String serverDate = dateFormat.format(new Date());

  // Simulated stats from DB
  int totalItems      = 18;
  int inStockCount    = 12;
  int damagedCount    = 6;
  int staffCheckouts  = 7;
  int lowStockCount   = 4;
  int outOfStockCount = 2;

  // Session / auth check (production)
  // HttpSession sess = request.getSession(false);
  // if (sess == null || sess.getAttribute("loggedInUser") == null) {
  //   response.sendRedirect("login.jsp");
  //   return;
  // }
  // String username = (String) sess.getAttribute("loggedInUser");
  String username = "Admin User";
  String userRole = "Store Manager";

  // Low stock items (simulated — from DB in production)
  String[][] lowStockItems = {
    {"Eggs",              "18",  "24",  "Low Stock"},
    {"Orange Juice",      "7",   "10",  "Low Stock"},
    {"Rice (25kg bag)",   "12",  "15",  "Low Stock"},
    {"Bleach Disinfectant","8",  "15",  "Low Stock"},
    {"Butter",            "0",   "5",   "Out of Stock"},
    {"Dishwashing Liquid","0",   "20",  "Out of Stock"},
  };

  // Recent activity (simulated)
  String[][] activities = {
    {"add",      "Added <strong>Fresh Milk (120L)</strong> to inventory",     "2 hours ago"},
    {"damage",   "Damage reported: <strong>Eggs (×24)</strong> broken",       "5 hours ago"},
    {"checkout", "<strong>James Otieno</strong> checked out Cooking Oil",     "Yesterday"},
    {"add",      "Added <strong>Bleach Disinfectant (×8)</strong>",           "2 days ago"},
    {"damage",   "<strong>Dishwashing Liquid</strong> written off",           "5 days ago"},
  };
%>

<div class="container-fluid p-0">
  <div class="main-wrapper" style="margin-left:0">

    <!-- Top bar (server rendered) -->
    <header class="topbar">
      <div class="topbar-left">
        <h2 class="page-title">Server-Side Dashboard</h2>
        <div class="breadcrumb-wrap">
          <span class="bc-item">INVENTORY management
          </span>
          <i class="fa-solid fa-chevron-right bc-sep"></i>
          <span class="bc-item active">Dashboard (JSP)</span>
        </div>
      </div>
      <div class="topbar-right">
        <div class="date-badge">
          <i class="fa-regular fa-calendar"></i>
          <span><%=serverDate%></span>
        </div>
        <div class="date-badge">
          <i class="fa-solid fa-user-tie"></i>
          <span><%=username%> — <%=userRole%></span>
        </div>
        <a href="index.html" class="btn-primary-action" style="text-decoration:none;">
          <i class="fa-solid fa-arrow-left"></i> Back to App
        </a>
      </div>
    </header>

    <div class="page-container">

      <!-- JSP Info Banner -->
      <div class="alert-item" style="margin-bottom:24px;border-left:3px solid var(--accent-cyan);border-radius:var(--radius-md);background:rgba(6,182,212,0.08);">
        <span class="alert-item-icon" style="color:var(--accent-cyan);font-size:18px;"><i class="fa-brands fa-java"></i></span>
        <div style="flex:1">
          <strong style="color:var(--accent-cyan)">Server-Side JSP Rendering</strong>
          <div style="font-size:12px;color:var(--text-muted);margin-top:3px;">
            This page demonstrates how InvenTrack Pro data would be rendered server-side using Java Server Pages.
            In production, data is fetched from a database via a Java service layer and injected into the JSP context.
          </div>
        </div>
      </div>

      <!-- Stats Row -->
      <div class="row g-4 mb-4">
        <div class="col-xl-3 col-md-6">
          <div class="stat-card shake-card" data-color="blue">
            <div class="stat-icon"><i class="fa-solid fa-boxes-stacked"></i></div>
            <div class="stat-info">
              <span class="stat-label">Total Items</span>
              <span class="stat-value"><%=totalItems%></span>
              <span class="stat-trend up"><i class="fa-solid fa-arrow-trend-up"></i> Server rendered</span>
            </div>
            <div class="stat-bg-icon"><i class="fa-solid fa-boxes-stacked"></i></div>
          </div>
        </div>
        <div class="col-xl-3 col-md-6">
          <div class="stat-card shake-card" data-color="green">
            <div class="stat-icon"><i class="fa-solid fa-circle-check"></i></div>
            <div class="stat-info">
              <span class="stat-label">In Stock</span>
              <span class="stat-value"><%=inStockCount%></span>
              <span class="stat-trend up"><i class="fa-solid fa-arrow-trend-up"></i> Java rendered</span>
            </div>
            <div class="stat-bg-icon"><i class="fa-solid fa-circle-check"></i></div>
          </div>
        </div>
        <div class="col-xl-3 col-md-6">
          <div class="stat-card shake-card" data-color="red">
            <div class="stat-icon"><i class="fa-solid fa-triangle-exclamation"></i></div>
            <div class="stat-info">
              <span class="stat-label">Damaged Items</span>
              <span class="stat-value"><%=damagedCount%></span>
              <span class="stat-trend down"><i class="fa-solid fa-arrow-trend-down"></i> DB count</span>
            </div>
            <div class="stat-bg-icon"><i class="fa-solid fa-triangle-exclamation"></i></div>
          </div>
        </div>
        <div class="col-xl-3 col-md-6">
          <div class="stat-card shake-card" data-color="amber">
            <div class="stat-icon"><i class="fa-solid fa-users"></i></div>
            <div class="stat-info">
              <span class="stat-label">Staff Checkouts</span>
              <span class="stat-value"><%=staffCheckouts%></span>
              <span class="stat-trend up"><i class="fa-solid fa-arrow-trend-up"></i> This month</span>
            </div>
            <div class="stat-bg-icon"><i class="fa-solid fa-users"></i></div>
          </div>
        </div>
      </div>

      <div class="row g-4">
        <!-- Low Stock Table (server rendered) -->
        <div class="col-xl-7">
          <div class="card-panel shake-card">
            <div class="panel-header">
              <h5><i class="fa-solid fa-triangle-exclamation"></i> Low Stock Items (Server Rendered)</h5>
              <span class="badge badge-warn"><%=lowStockCount + outOfStockCount%> Alerts</span>
            </div>
            <div class="table-responsive">
              <table class="table table-dark-custom">
                <thead>
                  <tr>
                    <th>Item Name</th>
                    <th>Current Qty</th>
                    <th>Min Level</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  <%
                    for (String[] item : lowStockItems) {
                      String statusClass = item[3].equals("Out of Stock") ? "red" : "amber";
                  %>
                  <tr>
                    <td><strong><%=item[0]%></strong></td>
                    <td style="font-family:'JetBrains Mono',monospace"><%=item[1]%></td>
                    <td style="font-family:'JetBrains Mono',monospace;color:var(--text-muted)"><%=item[2]%></td>
                    <td><span class="badge badge-<%=statusClass%>"><%=item[3]%></span></td>
                  </tr>
                  <%
                    }
                  %>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <!-- Recent Activity (server rendered) -->
        <div class="col-xl-5">
          <div class="card-panel shake-card">
            <div class="panel-header">
              <h5><i class="fa-solid fa-clock-rotate-left"></i> Recent Activity</h5>
            </div>
            <div class="activity-list">
              <%
                for (String[] activity : activities) {
                  String iconClass = "fa-plus";
                  if (activity[0].equals("damage"))   iconClass = "fa-triangle-exclamation";
                  if (activity[0].equals("checkout")) iconClass = "fa-user-check";
              %>
              <div class="activity-item">
                <div class="activity-icon <%=activity[0]%>">
                  <i class="fa-solid <%=iconClass%>"></i>
                </div>
                <div class="activity-text"><%=activity[1]%></div>
                <div class="activity-time"><%=activity[2]%></div>
              </div>
              <%
                }
              %>
            </div>
          </div>
        </div>
      </div>

      <!-- Server Info Card -->
      <div class="row g-4 mt-0">
        <div class="col-12">
          <div class="card-panel shake-card" style="border-left:3px solid var(--navy-400)">
            <div class="panel-header">
              <h5><i class="fa-brands fa-java"></i> JSP Integration Notes</h5>
            </div>
            <div class="row g-3" style="font-size:13px;color:var(--text-secondary)">
              <div class="col-md-4">
                <div style="padding:14px;background:var(--navy-800);border-radius:var(--radius-sm);border:1px solid var(--border-color)">
                  <div style="color:var(--accent-cyan);font-weight:700;margin-bottom:8px;font-size:12px;letter-spacing:1px;text-transform:uppercase">Database Layer</div>
                  Connect via JNDI DataSource or direct JDBC. Use PreparedStatements for all queries. Recommended: connection pooling with HikariCP or Tomcat JDBC Pool.
                </div>
              </div>
              <div class="col-md-4">
                <div style="padding:14px;background:var(--navy-800);border-radius:var(--radius-sm);border:1px solid var(--border-color)">
                  <div style="color:var(--accent-amber);font-weight:700;margin-bottom:8px;font-size:12px;letter-spacing:1px;text-transform:uppercase">Session Management</div>
                  Use <code style="color:var(--accent-cyan)">HttpSession</code> for user authentication. Store user role, permissions, and audit trail. Invalidate on logout.
                </div>
              </div>
              <div class="col-md-4">
                <div style="padding:14px;background:var(--navy-800);border-radius:var(--radius-sm);border:1px solid var(--border-color)">
                  <div style="color:var(--accent-green);font-weight:700;margin-bottom:8px;font-size:12px;letter-spacing:1px;text-transform:uppercase">API Endpoint</div>
                  <code style="color:var(--accent-cyan)">inventoryApi.jsp</code> handles all JSON REST calls. Frontend JS calls this endpoint for live CRUD operations in production.
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

    </div><!-- page-container -->
  </div><!-- main-wrapper -->
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
