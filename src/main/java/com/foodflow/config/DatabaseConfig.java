package com.foodflow.config;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

public class DatabaseConfig {

    private static final String DB_URL = getEnvOrDefault("FOODFLOW_DB_URL", "jdbc:mysql://localhost:3306/foodflow");
    private static final String DB_USER = getEnvOrDefault("FOODFLOW_DB_USER", "root");
    private static final String DB_PASSWORD = getEnvOrDefault("FOODFLOW_DB_PASSWORD", "CosHar#123");

    static {
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
        } catch (ClassNotFoundException e) {
            throw new IllegalStateException("MySQL JDBC Driver not found.", e);
        }
    }

    public static Connection getConnection() {
        try {
            return DriverManager.getConnection(DB_URL, DB_USER, DB_PASSWORD);
        } catch (SQLException e) {
            throw new IllegalStateException("Unable to create database connection.", e);
        }
    }

    private static String getEnvOrDefault(String name, String defaultValue) {
        String value = System.getenv(name);
        if (value == null || value.trim().isEmpty()) {
            return defaultValue;
        }
        return value.trim();
    }
}
