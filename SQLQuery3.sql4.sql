
-- 1. Count the total number of products in the database
SELECT COUNT(*) AS total_products
FROM production.products;

-- 2. Find the average, minimum, and maximum price of all products
SELECT 
    AVG(list_price) AS avg_price,
    MIN(list_price) AS min_price,
    MAX(list_price) AS max_price
FROM production.products;

-- 3. Count how many products are in each category
SELECT c.category_name, COUNT(p.product_id) AS product_count
FROM production.products p
JOIN production.categories c ON p.category_id = c.category_id
GROUP BY c.category_name;

-- 4. Find the total number of orders for each store
SELECT s.store_name, COUNT(o.order_id) AS total_orders
FROM sales.orders o
JOIN sales.stores s ON o.store_id = s.store_id
GROUP BY s.store_name;

-- 5. Show customer first names in UPPERCASE and last names in lowercase for the first 10 customers
SELECT TOP 10 
    UPPER(first_name) AS first_name_upper,
    LOWER(last_name) AS last_name_lower
FROM sales.customers;

-- 6. Get the length of each product name. Show product name and its length for the first 10 products
SELECT TOP 10 
    product_name,
    LEN(product_name) AS name_length
FROM production.products;

-- 7. Format customer phone numbers to show only the area code (first 3 digits) for customers 1-15
SELECT TOP 15 
    customer_id,
    phone,
    LEFT(phone, 3) AS area_code
FROM sales.customers;

-- 8. Show the current date and extract the year and month from order dates for orders 1-10

SELECT TOP 10 
    order_id,
    order_date,
    YEAR(order_date) AS year_part,
    MONTH(order_date) AS month_part,
    GETDATE() AS today_date
FROM sales.orders;

-- 9. Join products with their categories. Show product name and category name for first 10 products
SELECT TOP 10 
    p.product_name, 
    c.category_name
FROM production.products p
JOIN production.categories c ON p.category_id = c.category_id;

-- 10. Join customers with their orders. Show customer name and order date for first 10 orders
SELECT TOP 10 
    c.first_name + ' ' + c.last_name AS customer_name,
    o.order_date
FROM sales.orders o
JOIN sales.customers c ON o.customer_id = c.customer_id;

-- 11. Show all products with their brand names, even if some products don't have brands
SELECT 
    p.product_name,
    ISNULL(b.brand_name, 'No Brand') AS brand_name
FROM production.products p
LEFT JOIN production.brands b ON p.brand_id = b.brand_id;

-- 12. Find products that cost more than the average product price
SELECT 
    product_name, 
    list_price
FROM production.products
WHERE list_price > (SELECT AVG(list_price) FROM production.products);

-- 13. Find customers who have placed at least one order (using subquery with IN)
SELECT customer_id, first_name + ' ' + last_name AS customer_name
FROM sales.customers
WHERE customer_id IN (
    SELECT DISTINCT customer_id FROM sales.orders
);

-- 14. For each customer, show their name and total number of orders using a subquery in the SELECT clause
SELECT 
    c.customer_id,
    c.first_name + ' ' + c.last_name AS customer_name,
    (SELECT COUNT(*) FROM sales.orders o WHERE o.customer_id = c.customer_id) AS total_orders
FROM sales.customers c;

-- 15. Create a view called easy_product_list and query products with price > 100 from it
CREATE VIEW production.easy_product_list AS
SELECT 
    p.product_name, 
    c.category_name, 
    p.list_price
FROM production.products p
JOIN production.categories c ON p.category_id = c.category_id;

-- Query from the view
SELECT * FROM production.easy_product_list WHERE list_price > 100;

-- 16. Create a view called customer_info and use it to find all customers from California (CA)
CREATE VIEW sales.customer_info AS
SELECT 
    customer_id,
    first_name + ' ' + last_name AS full_name,
    email,
    city + ', ' + state AS city_state
FROM sales.customers;

-- Query from the view
SELECT * FROM sales.customer_info WHERE city_state LIKE '%, CA';

-- 17. Find all products that cost between $50 and $200, ordered by price ascending
SELECT 
    product_name, 
    list_price
FROM production.products
WHERE list_price BETWEEN 50 AND 200
ORDER BY list_price ASC;

-- 18. Count how many customers live in each state
SELECT 
    state, 
    COUNT(*) AS customer_count
FROM sales.customers
GROUP BY state
ORDER BY customer_count DESC;

-- 19. Find the most expensive product in each category
SELECT 
    c.category_name,
    p.product_name,
    p.list_price
FROM production.products p
JOIN production.categories c ON p.category_id = c.category_id
WHERE p.list_price = (
    SELECT MAX(p2.list_price)
    FROM production.products p2
    WHERE p2.category_id = p.category_id
);

-- 20. Show all stores and their cities, including the total number of orders from each store
SELECT 
    s.store_name,
    s.city,
    COUNT(o.order_id) AS order_count
FROM sales.stores s
LEFT JOIN sales.orders o ON s.store_id = o.store_id
GROUP BY s.store_name, s.city;
