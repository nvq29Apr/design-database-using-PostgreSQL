--NGUYEN CONG NHUAN 20215108 
--SELECT
--1, Chọn ra các Laptop có giá dưới 20tr, kích thước màn hình 15.6 inch, RAM 8GB
SELECT p.product_name, p.product_price, p.original_price, p.manufacturer, p.total_sale
FROM products p JOIN categories c USING(categoryid)
WHERE c.category_name = 'Laptop'
    AND p.product_price <= 20000000
    AND p.display_size = 15.6
    AND memory = 8;
--2, Sản phẩm bán chạy nhất trong danh mục “Smartwatch”
SELECT p.product_name, p.product_price, p.original_price, p.manufacturer, p.total_sale
FROM products p, categories c
WHERE p.categoryid = c.categoryid
    AND category_name = 'Smartwatch'
ORDER BY total_sale DESC;
--3, Xem feedback ve san pham Samsung Galaxy Z Fold4 5G
SELECT c.first_name || ' ' || c.last_name fullname, f.rate || '*' rate, f.comments, f.feedback_date, f.media1, f.media2, f.purchased_date
FROM products p JOIN feedback f  USING(productid) JOIN customers c USING(customerid)
WHERE p.product_name = 'Samsung Galaxy Z Fold4 5G';

--4, Các danh mục được bán
SELECT category_name 
FROM categories;

--5, Sản phẩm của Apple có giá thấp nhất
SELECT p.product_name, p.product_price, p.total_sale, p.stock
FROM products p
WHERE p.manufacturer = 'Apple'
    AND p.product_price = (SELECT MIN(product_price) FROM products WHERE manufacturer = 'Apple');

--6, Hiển thị các laptop theo giá tăng dần
SELECT p.product_name, p.product_price, p.original_price, p.manufacturer, p.total_sale
FROM products p JOIN categories c USING(categoryid)
WHERE c.category_name = 'Laptop'
ORDER BY p.product_price;

--7, Hiển thị các iPad có kích thước màn hình lớn hơn 10 inch
SELECT p.product_name, p.product_price, p.total_sale, p.stock
FROM products p
WHERE p.product_name ILIKE '%ipad%'
    AND p.display_size > 10;

--8, Phụ kiện bán chạy nhất
SELECT p.product_name, p.product_price, p.original_price, p.manufacturer, p.total_sale, p.stock
FROM products p JOIN categories c USING(categoryid)
WHERE c.category_name = 'Accessory'
ORDER BY p.total_sale;

--9, Các sản phẩm đang 'cháy hàng'
SELECT p.product_name, p.product_price, p.original_price, p.manufacturer, p.total_sale, p.stock
FROM products p
WHERE p.stock = 0;

--10, Đơn hàng có giá trị đơn hàng lớn nhất trong tháng 5/2023
SELECT * FROM orders o
WHERE order_price = (SELECT MAX(order_price) FROM orders)
    AND order_date BETWEEN '2023-05-01' AND '2023-05-31';

--NGUYEN VAN QUYET 20215129
--FUNCTION
--1, Tim kiem san pham
CREATE OR REPLACE FUNCTION search(_searchkey varchar)
RETURNS TABLE (
    product_name varchar, 
    product_price int, 
    discount int, 
    priginal_price int
)
LANGUAGE plpgsql
AS
$$
BEGIN
    RETURN QUERY
    SELECT p.product_name, p.product_price, p.discount, p.original_price
    FROM products p
    WHERE p.product_name ILIKE '%' || _searchkey || '%';
END
$$;
--2, Lich su mua hang theo username
CREATE OR REPLACE FUNCTION purchase_history(_username varchar)
RETURNS TABLE (
    orderid int,
    order_date date, 
    order_count int, 
    order_price int,
    order_status varchar,
    payment_method varchar
)
LANGUAGE plpgsql
AS
$$
BEGIN
    RETURN QUERY
    SELECT o.orderid, o.order_date, o.order_count, o.order_price, o.order_status, o.payment_method
    FROM customers c JOIN orders o USING(customerid)
    WHERE c.username = _username
    ORDER BY o.order_date DESC;
END
$$;
SELECT * FROM purchase_history('minhcute');
--3, Tra cuu chi tiet don hang theo ma don hang
CREATE OR REPLACE FUNCTION detail_order(_orderid int)
RETURNS TABLE (
    product_name varchar,
    quantity smallint, 
    product_price int,
    subtotal_price int
)
LANGUAGE plpgsql
AS
$$
BEGIN
    RETURN QUERY
    SELECT p.product_name, ol.quantity, p.product_price, ol.quantity * p.product_price AS subtotal_price
    FROM orderlines ol JOIN products p USING(productid)
    WHERE ol.orderid = _orderid;
END
$$;
-- MOT SO FUNCTION KHAC
--, Top san pham ban chay theo danh muc
CREATE OR REPLACE FUNCTION BestSeller(category_name1 varchar)
RETURNS TABLE(
    product_name varchar, 
    product_price int, 
    original_price int, 
    manufacturer varchar, 
    total_sale int)
    LANGUAGE plpgsql
AS
$$
BEGIN
	RETURN QUERY
    SELECT p.product_name, p.product_price, p.original_price, p.manufacturer, p.total_sale
    FROM products p, categories c
    WHERE p.categoryid = c.categoryid
        AND category_name = category_name1
	ORDER BY total_sale DESC;
END
$$;
SELECT * FROM bestseller('Smartphone');
-- Thay doi mat khau
CREATE OR REPLACE FUNCTION change_pw(_username varchar, o_password varchar, n_password varchar)
RETURNS VOID AS
$$
DECLARE current_pw varchar(50) = null;
BEGIN
SELECT password into current_pw FROM customers WHERE username = _username;
IF(current_pw = o_password)
THEN
	UPDATE customers
    SET password = n_password
    WHERE username = _username;
	RAISE NOTICE 'Thay doi mat khau thanh cong!';
ELSE 
	RAISE WARNING 'Mat khau cu khong dung!';
	
END IF;
END;
$$ LANGUAGE plpgsql
RETURNS NULL ON NULL INPUT;
SELECT change_pw('minhcute', '20215092', '123456');
--INDEX
CREATE INDEX idx_product_price ON products(product_price);

-- NGUYEN VAN MINH 20215092 
-- TRIGGER
-- 1. Trigger tính customers.cart_count sau khi thêm hoặc xóa trên bảng cartlines
create or replace function fnc_cart_count()
returns trigger as
$$
begin
	case
		when TG_OP = 'INSERT' then
			update customers
			set cart_count = cart_count + 1
			where customerid = new.customerid;
		when TG_OP = 'DELETE' then
			update cart
			set cart_count = cart_count - 1
			where customerid = old.customerid;
	else
		raise NOTICE 'Trigger % may be not working properly!', TG_NAME;
	end case;
	
	raise NOTICE 'trigger % has been running', TG_NAME;
	return null;
end;
$$
language plpgsql;

create or replace trigger tg_customers_1
after insert or delete on cartlines
for each row
execute procedure fnc_cart_count();
-- 2. Trigger tính customers.total_paid sau khi có update orders.order_status = 'order delivered'
create or replace function fnc_total_paid()
returns trigger as
$$
begin
    update customers
    set total_paid = total_paid + (select order_price from orders where orderid = old.orderid)
    where customerid = old.customerid;
    
    raise NOTICE 'trigger % has been running', TG_NAME;
    return null;
end;
$$
language plpgsql;

create or replace trigger tg_customers_2
after update on orders
for each row
when ((new.order_status is distinct from old.order_status) and (new.order_status = 'delivered'))
execute procedure fnc_total_paid();
-- 3. Trigger tính products.product_price khi thêm sản phẩm hay sau khi có thay đổi trên trường products.discount hay trường products.original_price
-- Trường discount và original_price đã được đặt là NOT NULL khi create table products
create or replace function fnc_product_price()
returns trigger as
$$
begin
	new.product_price = new.original_price/100*(100-new.discount);

	raise NOTICE 'trigger % have been running', TG_NAME;
	return new;
end;
$$
language plpgsql;

create or replace trigger tg_products_10
before insert on products
for each row
execute procedure fnc_product_price();

create or replace trigger tg_products_11
after update on products
for each row
when ((new.discount <> old.discount) or (new.original_price <> old.original_price))
execute procedure fnc_product_price();
-- 4. Trigger tính total_sale, stock sau khi có thay đổi trên bảng orderlines
create or replace function fnc_total_sale_stock()
returns trigger as
$$
begin
	case
	when TG_OP = 'INSERT' then
		update products
		set total_sale = total_sale + new.quantity,
			stock = stock - new.quantity
		where productid = new.productid;
	
	when TG_OP = 'DELETE' then
		update products
		set total_sale = total_sale - old.quantity,
			stock = stock + old.quantity
		where productid = old.productid;

	when TG_OP = 'UPDATE' then
		if new.productid <> old.productid then
			update products
			set total_sale = total_sale - old.quantity,
				stock = stock + old.quantity
			where productid = old.productid;
			
			update products
			set total_sale = total_sale + new.quantity,
				stock = stock - new.quantity
			where productid = new.productid;
		else
			if new.quantity <> old.quantity then
			update products
			set total_sale = total_sale - old.quantity + new.quantity,
				stock = stock + old.quantity - new.quantity
			where productid = new.productid;
			end if;
		end if;
	else
		raise NOTICE 'Trigger % may be not working properly!', TG_NAME;
	end case;
	
	raise NOTICE 'trigger % have been running', TG_NAME;
	return null;
end;
$$
language plpgsql;

create or replace trigger tg_products_2
after insert or update or delete on orderlines
for each row
execute procedure fnc_total_sale_stock();
-- 5. Trigger tính orders.order_price, orders.order_count sau khi có thay đổi trên bảng orderlines
create or replace function fnc_orders_1()
returns trigger as
$$
declare
	new_price integer = null;
	old_price integer = null;
begin
	case
	when TG_OP = 'INSERT' then
		select product_price into new_price from products where productid = new.productid;
		update orders
		set order_price = order_price + new_price*new.quantity,
			order_count = order_count + 1
		where orderid = new.orderid;
	
	when TG_OP = 'DELETE' then
		select product_price into old_price	from products where productid = old.productid;
		update orders
		set order_price = order_price - old_price*old.quantity,
			order_count = order_count - 1
		where orderid = old.orderid;
	
	when TG_OP = 'UPDATE' then
		if new.productid <> old.productid then
			select product_price into new_price	from products where productid = new.productid;
			select product_price into old_price	from products where productid = old.productid;
			update orders
			set order_price = order_price - old_price*old.quantity + new_price*new.quantity
			where orderid = new.orderid;
		else
			if new.quantity <> old.quantity then
			select product_price into new_price	from products where productid = new.productid;
			update orders
			set order_price = order_price + new_price*(new.quantity-old.quantity)
			where orderid = new.orderid;
			end if;
		end if;
	else
		raise NOTICE 'Trigger % may be not working properly!', TG_NAME;
	end case;
    raise NOTICE 'trigger % has been running', TG_NAME;
    return null;
end;
$$
language plpgsql;

create or replace trigger tg_orders_1
after insert or update or delete on orderlines
for each row
execute procedure fnc_orders_1();
-- 6. Trigger insert purchased_date khi người dùng có phản hồi về sản phẩm
create or replace function fnc_purchased_date()
returns trigger as
$$
declare
	buy_date date = null;
begin
	select order_date into buy_date
	from orders join orderlines using(orderid)
	where customerid = new.customerid and productid = new.productid and order_status = 'delivered';
	
	if buy_date is null then
		raise NOTICE 'you must have purchased to feedback';
		return null;
	else
		new.purchased_date = buy_date;
		return new;
	end if;
	raise NOTICE 'trigger % have been running', TG_NAME;
end;
$$
language plpgsql;

create or replace trigger tg_feedback_1
before insert or update on feedback
for each row
execute procedure fnc_purchased_date();
