
DECLARE @CustomerID INT = 1;
DECLARE @TotalSpent DECIMAL(10, 2);

SELECT @TotalSpent = SUM(oi.quantity * oi.list_price * (1 - oi.discount))
FROM sales.orders o
JOIN sales.order_items oi ON o.order_id = oi.order_id
WHERE o.customer_id = @CustomerID;

SELECT 
    'Customer ' + CAST(@CustomerID AS VARCHAR) + 
    ' is a ' + 
    CASE 
        WHEN @TotalSpent > 5000 THEN 'VIP customer'
        ELSE 'Regular customer'
    END + ' (Total Spent: $' + CAST(@TotalSpent AS VARCHAR) + ')' AS Status;

DECLARE @Threshold DECIMAL(10, 2) = 1500;
DECLARE @ProductCount INT;

SELECT @ProductCount = COUNT(*)
FROM production.products
WHERE list_price > @Threshold;

SELECT 
    'Threshold: $' + CAST(@Threshold AS VARCHAR) + 
    ', Products Above Threshold: ' + CAST(@ProductCount AS VARCHAR) AS Report;

DECLARE @StaffID INT = 2;
DECLARE @Year INT = 2017;
DECLARE @TotalSales DECIMAL(10, 2);

SELECT @TotalSales = SUM(oi.quantity * oi.list_price * (1 - oi.discount))
FROM sales.orders o
JOIN sales.order_items oi ON o.order_id = oi.order_id
WHERE o.staff_id = @StaffID AND YEAR(o.order_date) = @Year;

SELECT 'Staff ID: ' + CAST(@StaffID AS VARCHAR) + 
       ', Year: ' + CAST(@Year AS VARCHAR) + 
       ', Total Sales: $' + CAST(@TotalSales AS VARCHAR) AS Summary;

SELECT 
    @@SERVERNAME AS ServerName,
    @@VERSION AS SQLVersion,
    @@ROWCOUNT AS RowsAffected;

DECLARE @Qty INT;

SELECT @Qty = quantity
FROM production.stocks
WHERE product_id = 1 AND store_id = 1;

IF @Qty > 20
    PRINT 'Well stocked';
ELSE IF @Qty BETWEEN 10 AND 20
    PRINT 'Moderate stock';
ELSE
    PRINT 'Low stock - reorder needed';

DECLARE @Counter INT = 0;

WHILE @Counter < 1
BEGIN
    UPDATE TOP (3) production.stocks
    SET quantity = quantity + 10
    WHERE quantity < 5;

    IF @@ROWCOUNT = 0
        BREAK;

    PRINT 'Updated batch of 3 low-stock items.';

    SET @Counter = @Counter + 1;
END

SELECT 
    product_name,
    list_price,
    CASE 
        WHEN list_price < 300 THEN 'Budget'
        WHEN list_price BETWEEN 300 AND 800 THEN 'Mid-Range'
        WHEN list_price BETWEEN 801 AND 2000 THEN 'Premium'
        ELSE 'Luxury'
    END AS Category
FROM production.products;

DECLARE @CustID INT = 5;

IF EXISTS (SELECT 1 FROM sales.customers WHERE customer_id = @CustID)
BEGIN
    SELECT COUNT(*) AS OrderCount
    FROM sales.orders
    WHERE customer_id = @CustID;
END
ELSE
BEGIN
    PRINT 'Customer ID 5 does not exist.';
END

CREATE FUNCTION dbo.CalculateShipping(@OrderTotal DECIMAL(10,2))
RETURNS DECIMAL(10,2)
AS
BEGIN
    RETURN (
        CASE
            WHEN @OrderTotal > 100 THEN 0
            WHEN @OrderTotal BETWEEN 50 AND 99.99 THEN 5.99
            ELSE 12.99
        END
    )
END;

CREATE FUNCTION dbo.GetProductsByPriceRange(@MinPrice DECIMAL(10,2), @MaxPrice DECIMAL(10,2))
RETURNS TABLE
AS
RETURN
    SELECT p.product_name, p.list_price, b.brand_name, c.category_name
    FROM production.products p
    JOIN production.brands b ON p.brand_id = b.brand_id
    JOIN production.categories c ON p.category_id = c.category_id
    WHERE p.list_price BETWEEN @MinPrice AND @MaxPrice;

CREATE FUNCTION dbo.GetCustomerYearlySummary(@CustomerID INT)
RETURNS @Summary TABLE (
    OrderYear INT,
    TotalOrders INT,
    TotalSpent DECIMAL(10,2),
    AvgOrderValue DECIMAL(10,2)
)
AS
BEGIN
    INSERT INTO @Summary
    SELECT 
        YEAR(o.order_date),
        COUNT(DISTINCT o.order_id),
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)),
        AVG(oi.quantity * oi.list_price * (1 - oi.discount))
    FROM sales.orders o
    JOIN sales.order_items oi ON o.order_id = oi.order_id
    WHERE o.customer_id = @CustomerID
    GROUP BY YEAR(o.order_date);
    RETURN;
END;

CREATE FUNCTION dbo.CalculateBulkDiscount(@Quantity INT)
RETURNS DECIMAL(4,2)
AS
BEGIN
    RETURN (
        CASE 
            WHEN @Quantity BETWEEN 1 AND 2 THEN 0.00
            WHEN @Quantity BETWEEN 3 AND 5 THEN 0.05
            WHEN @Quantity BETWEEN 6 AND 9 THEN 0.10
            ELSE 0.15
        END
    )
END;

CREATE PROCEDURE sp_GetCustomerOrderHistory
    @CustomerID INT,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SELECT o.order_id, o.order_date,
           SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS OrderTotal
    FROM sales.orders o
    JOIN sales.order_items oi ON o.order_id = oi.order_id
    WHERE o.customer_id = @CustomerID
        AND (@StartDate IS NULL OR o.order_date >= @StartDate)
        AND (@EndDate IS NULL OR o.order_date <= @EndDate)
    GROUP BY o.order_id, o.order_date;
END;

CREATE PROCEDURE sp_RestockProduct
    @StoreID INT,
    @ProductID INT,
    @RestockQty INT,
    @OldQty INT OUTPUT,
    @NewQty INT OUTPUT,
    @Success BIT OUTPUT
AS
BEGIN
    SET @Success = 0;

    SELECT @OldQty = quantity
    FROM production.stocks
    WHERE store_id = @StoreID AND product_id = @ProductID;

    IF @OldQty IS NOT NULL
    BEGIN
        UPDATE production.stocks
        SET quantity = quantity + @RestockQty
        WHERE store_id = @StoreID AND product_id = @ProductID;

        SELECT @NewQty = quantity
        FROM production.stocks
        WHERE store_id = @StoreID AND product_id = @ProductID;

        SET @Success = 1;
    END
END;

CREATE PROCEDURE sp_ProcessNewOrder
    @CustomerID INT,
    @ProductID INT,
    @Quantity INT,
    @StoreID INT
AS
BEGIN
    DECLARE @OrderID INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO sales.orders (customer_id, order_status, order_date, required_date, store_id, staff_id)
        VALUES (@CustomerID, 1, GETDATE(), DATEADD(DAY, 7, GETDATE()), @StoreID, 1);

        SET @OrderID = SCOPE_IDENTITY();

        INSERT INTO sales.order_items (order_id, item_id, product_id, quantity, list_price, discount)
        SELECT @OrderID, 1, @ProductID, @Quantity, list_price, 0
        FROM production.products
        WHERE product_id = @ProductID;

        COMMIT;
    END TRY
    BEGIN CATCH
        ROLLBACK;
        THROW;
    END CATCH;
END;

CREATE PROCEDURE sp_SearchProducts
    @Name NVARCHAR(100) = NULL,
    @CategoryID INT = NULL,
    @MinPrice DECIMAL(10,2) = NULL,
    @MaxPrice DECIMAL(10,2) = NULL,
    @SortColumn NVARCHAR(50) = NULL
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX) = 'SELECT * FROM production.products WHERE 1=1';

    IF @Name IS NOT NULL
        SET @SQL += ' AND product_name LIKE ''%' + @Name + '%''';
    IF @CategoryID IS NOT NULL
        SET @SQL += ' AND category_id = ' + CAST(@CategoryID AS NVARCHAR);
    IF @MinPrice IS NOT NULL
        SET @SQL += ' AND list_price >= ' + CAST(@MinPrice AS NVARCHAR);
    IF @MaxPrice IS NOT NULL
        SET @SQL += ' AND list_price <= ' + CAST(@MaxPrice AS NVARCHAR);
    IF @SortColumn IS NOT NULL
        SET @SQL += ' ORDER BY ' + QUOTENAME(@SortColumn);

    EXEC sp_executesql @SQL;
END;

SELECT 
    s.product_id,
    s.store_id,
    s.quantity,
    p.category_id,
    CASE 
        WHEN s.quantity < 5 AND p.category_id = 1 THEN 'Reorder 50 units'
        WHEN s.quantity < 10 AND p.category_id = 2 THEN 'Reorder 30 units'
        WHEN s.quantity < 20 THEN 'Reorder 10 units'
        ELSE 'Stock sufficient'
    END AS ReorderDecision
FROM production.stocks s
JOIN production.products p ON s.product_id = p.product_id;

SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    ISNULL(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 0) AS TotalSpent,
    CASE 
        WHEN SUM(oi.quantity * oi.list_price * (1 - oi.discount)) IS NULL THEN 'No Orders'
        WHEN SUM(oi.quantity * oi.list_price * (1 - oi.discount)) >= 10000 THEN 'Platinum'
        WHEN SUM(oi.quantity * oi.list_price * (1 - oi.discount)) >= 5000 THEN 'Gold'
        WHEN SUM(oi.quantity * oi.list_price * (1 - oi.discount)) >= 1000 THEN 'Silver'
        ELSE 'Bronze'
    END AS LoyaltyTier
FROM sales.customers c
LEFT JOIN sales.orders o ON c.customer_id = o.customer_id
LEFT JOIN sales.order_items oi ON o.order_id = oi.order_id
GROUP BY c.customer_id, c.first_name, c.last_name;

CREATE PROCEDURE sp_DiscontinueProduct
    @ProductID INT,
    @ReplacementProductID INT = NULL
AS
BEGIN
    DECLARE @PendingOrders INT;

    SELECT @PendingOrders = COUNT(*)
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    WHERE oi.product_id = @ProductID AND o.order_status IN (1, 2);

    IF @PendingOrders > 0
    BEGIN
        PRINT 'Cannot discontinue product. There are pending orders.';
        RETURN;
    END

    IF @ReplacementProductID IS NOT NULL
    BEGIN
        UPDATE sales.order_items
        SET product_id = @ReplacementProductID
        WHERE product_id = @ProductID;
    END

    DELETE FROM production.stocks WHERE product_id = @ProductID;
    DELETE FROM production.products WHERE product_id = @ProductID;

    PRINT 'Product discontinued successfully.';
END;
