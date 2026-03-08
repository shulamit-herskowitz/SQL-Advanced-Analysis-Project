Advanced SQL Data Analysis & Optimization Project
Project Overview
This repository contains a collection of advanced SQL solutions for complex data challenges, ranging from sales performance analysis to system optimization and algorithmic logic. The project demonstrates high-level proficiency in T-SQL, including the use of window functions, recursive queries, and dynamic programming within a database environment.

Key Technical Modules
1. Sales & Revenue Analysis (Part A)
Proportional Discount Allocation: Implemented a logic to distribute invoice-level discounts across individual line items based on their relative value.

Sales Performance Metrics: Calculated total sales, item quantities, and unique invoice counts per product.

Advanced Filtering: Identified specific sales patterns and salesperson achievements using complex joins and set operators (INTERSECT, EXCEPT).

2. System Performance & Request Optimization (Part B)
Burst Detection: Developed queries to identify "demanding users" by analyzing request density within specific time windows (RPM - Requests Per Minute).

Dynamic Programming (DP) in SQL: Solved a scheduling problem to maximize priority-weighted requests while avoiding time overlaps, using a recursive CTE approach.

Bottleneck Analysis: Identified intervals with the highest average wait times to detect system latency.

3. Algorithmic Logic & Data Manipulation (Part C, D, E)
Combinatorial Optimization: Solved the "3-Sum" problem to find triplets that reach a specific target sum with the maximum product.

Custom Functions (UDF): Created a robust string reversal function for specialized data formatting.

Hierarchical Data Filling: Implemented a "Group-By-Start" logic using LAG and SUM OVER to fill missing header information across data rows.

Technologies Used
Engine: Microsoft SQL Server (T-SQL)

Advanced Features:

Common Table Expressions (CTEs)

Window Functions (RANK, FIRST_VALUE, SUM OVER)

Temporary Tables and Recursive Logic
