<%@ page language="java" contentType="application/json; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*, java.text.SimpleDateFormat" %>
<%--
  ============================================================
  InvenTrack Pro — Inventory API Endpoint (inventoryApi.jsp)
  
  Handles server-side CRUD for inventory data.
  In production this would connect to a real database (MySQL/PostgreSQL).
  
  Endpoints:
    GET  ?action=getItems         — fetch all items
    GET  ?action=getDamaged       — fetch damaged records
    GET  ?action=getStaff         — fetch staff checkouts
    GET  ?action=getStats         — summary statistics
    POST ?action=addItem          — add new item
    POST ?action=reportDamage     — log damaged item
    POST ?action=staffCheckout    — log staff checkout
    POST ?action=markReturned&ref — mark item as returned
    POST ?action=writeOff&ref     — write off damaged item
    POST ?action=deleteItem&id    — delete item
  ============================================================
--%>
<%
  // ---- CORS / JSON Headers ----
  response.setHeader("Access-Control-Allow-Origin",  "*");
  response.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  response.setHeader("Access-Control-Allow-Headers", "Content-Type");
  response.setContentType("application/json");
  response.setCharacterEncoding("UTF-8");

  String action = request.getParameter("action");
  if (action == null) action = "";

  // ---- In production: replace with DB calls ----
  // DataSource ds = (DataSource) ctx.lookup("java:comp/env/jdbc/inventrackDS");
  // Connection con = ds.getConnection();

  SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd");
  String today = sdf.format(new Date());

  StringBuilder json = new StringBuilder();

  switch (action) {

    // ----------------------------------------------------------------
    case "getStats": {
      // In production: SELECT COUNT(*) queries from DB
      json.append("{");
      json.append("\"success\": true,");
      json.append("\"data\": {");
      json.append("  \"totalItems\": 18,");
      json.append("  \"inStock\": 12,");
      json.append("  \"lowStock\": 4,");
      json.append("  \"outOfStock\": 2,");
      json.append("  \"damagedTotal\": 6,");
      json.append("  \"underReview\": 3,");
      json.append("  \"writtenOff\": 3,");
      json.append("  \"staffCheckouts\": 7,");
      json.append("  \"pendingReturns\": 3,");
      json.append("  \"perishableCount\": 8,");
      json.append("  \"nonPerishCount\": 10");
      json.append("}");
      json.append("}");
      break;
    }

    // ----------------------------------------------------------------
    case "getItems": {
      // In production:
      // PreparedStatement ps = con.prepareStatement(
      //   "SELECT * FROM inventory_items ORDER BY added_date DESC"
      // );
      // ResultSet rs = ps.executeQuery();
      // while (rs.next()) { ... build JSON ... }
      json.append("{");
      json.append("\"success\": true,");
      json.append("\"count\": 18,");
      json.append("\"data\": [");
      json.append("  {\"id\":\"ITM-001\",\"name\":\"Fresh Milk\",\"category\":\"Perishable\",\"qty\":120,\"unit\":\"Litres\",\"status\":\"In Stock\"},");
      json.append("  {\"id\":\"ITM-009\",\"name\":\"Cooking Oil (5L)\",\"category\":\"Non-Perishable\",\"qty\":200,\"unit\":\"Pieces\",\"status\":\"In Stock\"}");
      json.append("]");
      json.append("}");
      break;
    }

    // ----------------------------------------------------------------
    case "getDamaged": {
      json.append("{");
      json.append("\"success\": true,");
      json.append("\"count\": 6,");
      json.append("\"data\": [");
      json.append("  {\"ref\":\"DMG-001\",\"itemName\":\"Eggs\",\"qtyDamaged\":24,\"damageType\":\"Broken\",\"status\":\"Under Review\"},");
      json.append("  {\"ref\":\"DMG-002\",\"itemName\":\"Dishwashing Liquid\",\"qtyDamaged\":10,\"damageType\":\"Water Damaged\",\"status\":\"Written Off\"}");
      json.append("]");
      json.append("}");
      break;
    }

    // ----------------------------------------------------------------
    case "getStaff": {
      json.append("{");
      json.append("\"success\": true,");
      json.append("\"count\": 7,");
      json.append("\"data\": [");
      json.append("  {\"ref\":\"CHK-001\",\"staffName\":\"James Otieno\",\"dept\":\"Kitchen\",\"itemName\":\"Cooking Oil (5L)\",\"qtyTaken\":5,\"status\":\"Pending Return\"},");
      json.append("  {\"ref\":\"CHK-002\",\"staffName\":\"Grace Chebet\",\"dept\":\"Housekeeping\",\"itemName\":\"Bleach Disinfectant\",\"qtyTaken\":3,\"status\":\"Consumed\"}");
      json.append("]");
      json.append("}");
      break;
    }

    // ----------------------------------------------------------------
    case "addItem": {
      if ("POST".equalsIgnoreCase(request.getMethod())) {
        String name     = request.getParameter("name");
        String category = request.getParameter("category");
        String qty      = request.getParameter("qty");
        String unit     = request.getParameter("unit");
        String minLevel = request.getParameter("minLevel");
        String expiry   = request.getParameter("expiry");
        String supplier = request.getParameter("supplier");

        if (name == null || category == null || qty == null) {
          response.setStatus(400);
          json.append("{\"success\": false, \"message\": \"Missing required fields: name, category, qty\"}");
          break;
        }

        int qtyInt = 0;
        try { qtyInt = Integer.parseInt(qty); } catch (NumberFormatException e) {
          response.setStatus(400);
          json.append("{\"success\": false, \"message\": \"Invalid qty value\"}");
          break;
        }

        // In production:
        // PreparedStatement ps = con.prepareStatement(
        //   "INSERT INTO inventory_items (name, category, qty, unit, min_level, expiry_date, supplier, status, added_date) VALUES (?,?,?,?,?,?,?,?,?)"
        // );
        // Determine status
        int min = 10;
        try { min = Integer.parseInt(minLevel); } catch (Exception ex) {}
        String status = qtyInt <= 0 ? "Out of Stock" : qtyInt <= min ? "Low Stock" : "In Stock";

        json.append("{");
        json.append("\"success\": true,");
        json.append("\"message\": \"Item added successfully\",");
        json.append("\"data\": {");
        json.append("  \"id\": \"ITM-NEW\",");
        json.append("  \"name\": \"").append(escapeJson(name)).append("\",");
        json.append("  \"category\": \"").append(escapeJson(category)).append("\",");
        json.append("  \"qty\": ").append(qtyInt).append(",");
        json.append("  \"unit\": \"").append(escapeJson(unit != null ? unit : "Pieces")).append("\",");
        json.append("  \"status\": \"").append(status).append("\",");
        json.append("  \"addedDate\": \"").append(today).append("\"");
        json.append("}");
        json.append("}");
      } else {
        response.setStatus(405);
        json.append("{\"success\": false, \"message\": \"Method not allowed. Use POST.\"}");
      }
      break;
    }

    // ----------------------------------------------------------------
    case "reportDamage": {
      if ("POST".equalsIgnoreCase(request.getMethod())) {
        String itemName   = request.getParameter("itemName");
        String qtyDamaged = request.getParameter("qtyDamaged");
        String damageType = request.getParameter("damageType");
        String reportedBy = request.getParameter("reportedBy");
        String dmgStatus  = request.getParameter("status");

        if (itemName == null || qtyDamaged == null || damageType == null || reportedBy == null) {
          response.setStatus(400);
          json.append("{\"success\": false, \"message\": \"Missing required fields\"}");
          break;
        }

        // In production: INSERT INTO damaged_items ...
        json.append("{");
        json.append("\"success\": true,");
        json.append("\"message\": \"Damage report filed successfully\",");
        json.append("\"data\": {");
        json.append("  \"ref\": \"DMG-NEW\",");
        json.append("  \"itemName\": \"").append(escapeJson(itemName)).append("\",");
        json.append("  \"qtyDamaged\": ").append(qtyDamaged).append(",");
        json.append("  \"damageType\": \"").append(escapeJson(damageType)).append("\",");
        json.append("  \"reportedBy\": \"").append(escapeJson(reportedBy)).append("\",");
        json.append("  \"status\": \"").append(dmgStatus != null ? escapeJson(dmgStatus) : "Under Review").append("\",");
        json.append("  \"date\": \"").append(today).append("\"");
        json.append("}");
        json.append("}");
      } else {
        response.setStatus(405);
        json.append("{\"success\": false, \"message\": \"Method not allowed. Use POST.\"}");
      }
      break;
    }

    // ----------------------------------------------------------------
    case "staffCheckout": {
      if ("POST".equalsIgnoreCase(request.getMethod())) {
        String staffName = request.getParameter("staffName");
        String dept      = request.getParameter("dept");
        String itemName  = request.getParameter("itemName");
        String qtyTaken  = request.getParameter("qtyTaken");

        if (staffName == null || dept == null || itemName == null || qtyTaken == null) {
          response.setStatus(400);
          json.append("{\"success\": false, \"message\": \"Missing required fields\"}");
          break;
        }

        // In production: INSERT INTO staff_checkouts + UPDATE inventory_items SET qty=qty-? ...
        json.append("{");
        json.append("\"success\": true,");
        json.append("\"message\": \"Staff checkout logged successfully\",");
        json.append("\"data\": {");
        json.append("  \"ref\": \"CHK-NEW\",");
        json.append("  \"staffName\": \"").append(escapeJson(staffName)).append("\",");
        json.append("  \"dept\": \"").append(escapeJson(dept)).append("\",");
        json.append("  \"itemName\": \"").append(escapeJson(itemName)).append("\",");
        json.append("  \"qtyTaken\": ").append(qtyTaken).append(",");
        json.append("  \"dateTaken\": \"").append(today).append("\",");
        json.append("  \"status\": \"Pending Return\"");
        json.append("}");
        json.append("}");
      } else {
        response.setStatus(405);
        json.append("{\"success\": false, \"message\": \"Method not allowed. Use POST.\"}");
      }
      break;
    }

    // ----------------------------------------------------------------
    case "markReturned": {
      String ref = request.getParameter("ref");
      if (ref == null || ref.isEmpty()) {
        response.setStatus(400);
        json.append("{\"success\": false, \"message\": \"ref parameter required\"}");
        break;
      }
      // In production: UPDATE staff_checkouts SET status='Returned' WHERE ref=?
      json.append("{\"success\": true, \"message\": \"Item marked as returned\", \"ref\": \"").append(escapeJson(ref)).append("\"}");
      break;
    }

    // ----------------------------------------------------------------
    case "writeOff": {
      String ref = request.getParameter("ref");
      if (ref == null || ref.isEmpty()) {
        response.setStatus(400);
        json.append("{\"success\": false, \"message\": \"ref parameter required\"}");
        break;
      }
      // In production: UPDATE damaged_items SET status='Written Off' WHERE ref=?
      json.append("{\"success\": true, \"message\": \"Item written off\", \"ref\": \"").append(escapeJson(ref)).append("\"}");
      break;
    }

    // ----------------------------------------------------------------
    case "deleteItem": {
      String id = request.getParameter("id");
      if (id == null || id.isEmpty()) {
        response.setStatus(400);
        json.append("{\"success\": false, \"message\": \"id parameter required\"}");
        break;
      }
      // In production: DELETE FROM inventory_items WHERE id=?
      json.append("{\"success\": true, \"message\": \"Item deleted\", \"id\": \"").append(escapeJson(id)).append("\"}");
      break;
    }

    // ----------------------------------------------------------------
    default: {
      response.setStatus(400);
      json.append("{");
      json.append("\"success\": false,");
      json.append("\"message\": \"Unknown or missing action parameter\",");
      json.append("\"availableActions\": [\"getStats\",\"getItems\",\"getDamaged\",\"getStaff\",\"addItem\",\"reportDamage\",\"staffCheckout\",\"markReturned\",\"writeOff\",\"deleteItem\"],");
      json.append("\"version\": \"1.0.0\",");
      json.append("\"system\": \"InvenTrack Pro\"");
      json.append("}");
    }
  }

  out.print(json.toString());

%>
<%!
  // ---- Helper: JSON-safe string escaping ----
  private String escapeJson(String s) {
    if (s == null) return "";
    return s.replace("\\", "\\\\")
            .replace("\"", "\\\"")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t");
  }
%>
