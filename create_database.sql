\c postgres
drop database project9 with (force);
create database project9;
\c project9
-- customers(customerid,first_name,last_name,dob,gender,address,email,phone,bank_name,bank_account,username,password,cart_count,total_paid)
-- products(productid,categoryid,product_name,chip,memory,storage,display_size,manufacturer,import_price,original_price,discount,product_price,stock,total_sale)
-- orders(orderid,customerid,order_date,payment_method,order_price,order_count,order_status)
-- orderlines(orderid,productid,quantity)
-- cartlines(customerid,productid,quantity)
-- categories(categoryid,category_name)
-- feedback(customerid,productid,feedback_date,perchased_date,comments,rate,media1,media2)
CREATE TABLE customers (
	customerid serial NOT NULL PRIMARY KEY,
	first_name character varying(50) NOT NULL,
	last_name character varying(50) NOT NULL,
	address character varying(50) NOT NULL,
	email character varying(50),
	phone character varying(10) NOT NULL,
	bank_name character varying(15),
	bank_account character varying(15),	
	username character varying(50) UNIQUE NOT NULL,
	password character varying(50) NOT NULL,
	dob date,
	gender character varying(1),
	cart_count integer DEFAULT 0,
	total_paid integer DEFAULT 0,
	CHECK (gender IN ('F', 'M')),
	CHECK (cart_count >= 0)
);
CREATE TABLE categories (
	categoryid serial NOT NULL PRIMARY KEY,
	category_name character varying(50) NOT NULL
);
CREATE TABLE products (
	productid serial NOT NULL PRIMARY KEY,
	categoryid integer NOT NULL REFERENCES categories(categoryid),
	product_name character varying(50) NOT NULL,
	chip character varying(50),
	memory integer,		-- Don vi la GB
	storage integer,	-- Don vi la GB
	display_size numeric(4,2),	-- Don vi la inch
	discount integer NOT NULL DEFAULT 0,
	original_price integer NOT NULL,
	import_price integer NOT NULL,
	manufacturer character varying(50),
	product_price integer,
	stock integer DEFAULT 0,
	total_sale integer DEFAULT 0,
	CHECK (original_price > import_price),
	CHECK (discount >= 0 and discount <100)
);
CREATE TABLE orders (
	orderid serial NOT NULL PRIMARY KEY,
	customerid integer REFERENCES customers(customerid),
	order_date date NOT NULL DEFAULT CURRENT_DATE,
	order_status character varying(30) DEFAULT 'new order',
	payment_method character varying(20) NOT NULL DEFAULT 'bank transfer',
	order_price integer DEFAULT 0,
	order_count integer DEFAULT 0,
	CHECK (order_status IN ('new order','order placed','in transit','delivered')),
	CHECK (payment_method IN ('COD', 'bank transfer'))
);
CREATE TABLE orderlines (
	orderid integer NOT NULL REFERENCES orders(orderid),
	productid integer NOT NULL REFERENCES products(productid),
	quantity smallint NOT NULL,
	CHECK (quantity > 0),
	PRIMARY KEY (orderid,productid)
);
CREATE TABLE cartlines (
	customerid integer NOT NULL REFERENCES customers(customerid),
	productid integer NOT NULL REFERENCES products(productid),
	quantity integer NOT NULL,
	CHECK (quantity > 0),
	PRIMARY KEY (customerid,productid)
);
CREATE TABLE feedback (
	customerid integer NOT NULL REFERENCES customers(customerid),
	productid integer NOT NULL REFERENCES products(productid),
	rate smallint NOT NULL,
	comments character varying(200),
	feedback_date date DEFAULT CURRENT_DATE,
	purchased_date date,
	media1 character varying(50),
	media2 character varying(50),
	CHECK (rate IN ('1','2','3','4','5')),
	CHECK (media1 IN ('image','video')),
	CHECK (media2 IN ('image','video')),
	PRIMARY KEY (customerid,productid)
);

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

-------- INSERT
INSERT INTO customers(first_name, last_name, address, email, phone, bank_account, bank_name, username, password, dob, gender)
VALUES 
    ('Nguyen Van', 'Minh', 'Ha Noi - Hai Ba Trung - 1 Dai Co Viet', 'minhnv@gmail.com', '0329994096', '4673648234', 'MB Bank', 'minhcute', '20215092', '2003-07-03', 'M'),
    ('Nguyen Van', 'Quyet', 'Hung Yen', 'quyetnv@gmail.com', '0888999343', '4673648234', 'Techcombank', 'minrrrtthpv', '00000', '1999-12-03', 'F'),
	('Nguyen Cong', 'Nhuan', 'Nghe An', 'nhuannc@gmail.com', '0329994096', '4673648234', 'VietinBank', 'nhuancv', '20215092', '1980-07-03', 'M'),
    ('Nguyen Thi', 'Loan', 'Hai Phong', 'loannt@gmail.com', '0999994096', '3333648234', 'MB Bank', 'tinhnt', '20210005092', '2012-07-03', 'F'),
    ('Phan Van', 'Duc', 'Quang Tri', 'ducpv@gmail.com', '0329994888', '4673648234', 'Techcombank', 'minhpv', '00000', '1999-07-03', 'M'),
    ('Nguyen Quang', 'Hai', 'Ha Noi', 'hainq@gmail.com', '0329994888', '4673648234', 'Techcombank', 'qqqqq', '00000', '1999-07-03', 'F');
	
INSERT INTO categories(category_name)
VALUES
	('Smartphone'),
	('Tablet'),
	('Laptop'),
	('Smartwatch'),
	('Accessory');

INSERT INTO products(categoryid, product_name, chip, memory, storage, display_size, discount, original_price, import_price, manufacturer, stock)
VALUES
    (1, 'iPhone 14 Pro Max', 'Apple A16 Bionic', 8, 512, 6.7, 10, 29990000, 25000000, 'Apple', 1944),
    (1, 'Samsung Galaxy Z Fold4 5G', 'Snapdragon 8+ Gen 1', 12, 512, 6.9, 24, 44490000, 30000000, 'Samsung', 2999),
    (1, 'OPPO Find N2 Flip 5G', 'MediaTek Dimensity 9000+ 8 nhân', 12, 512, 6.8, 0, 19990000, 13000000, 'Oppo', 7999),
    (1, 'realme C55', 'MediaTek Helio G88', 6, 128, 6.72, 4, 4990000, 2000000, 'realme', 99),
    (1, 'vivo Y16', 'MediaTek Helio P35', 4, 64, 6.51, 12, 3990000, 2000000, 'Vivo', 887),
	(2, 'Galaxy Tab S8 Ultra 5G', 'Snapdragon 8 Gen 1', 8, 128, 14.6, 0, 30990000, 24000000, 'Samsung', 595),
	(2, 'iPad 9 WiFi', 'Apple A13 Bionic', 4, 64, 10.2, 10, 8390000, 5000000, 'Apple', 7595),
	(2, 'iPad Pro M2 12.9 inch WiFi', 'Apple M2 8 nhân', 8, 128, 12.9, 3, 29990000, 22000000, 'Apple ', 5775),
	(2, 'Lenovo Tab M9', 'MediaTek Helio G80', 4, 64, 9, 8, 4590000, 2590000, 'Lenovo', 2598),
	(2, 'OPPO Pad Air', 'Snapdragon 680 8 nhân', 4, 128, 10.36, 0, 7990000, 5600000, 'Oppo', 822),
    (3, 'Lenovo Legion 5 15IAH7', 'Intel Core i5 Alder Lake - 12500H', 8, 512, 15.6, 9, 35490000, 25000000, 'Lenovo', 555), 
    (3, 'Apple MacBook Air 13 inch M1 2020', 'Apple M1', 8, 256, 13.3, 0, 18990000, 14800000, 'Apple', 675), 
    (3, 'HP 240 G8 i3 1115G4', 'Intel Core i3 Tiger Lake - 1115G4', 8, 256, 14, 24, 12990000, 8150000, 'HP', 2781), 
    (3, 'MSI Gaming GF63 Thin 11SC i5 11400H', 'Intel Core i5 Tiger Lake - 11400H', 8, 512, 15.6, 9, 16490000, 11500000, 'MSI', 2672), 
    (3, 'Acer Aspire 7 Gaming A715 76G 5132 i5 12450H', 'Intel Core i5 Alder Lake - 12450H', 8, 512, 15.6, 15, 18990000, 14000000, 'Acer', 1406), 
    (4, 'Xiaomi Watch S1 46.5mm', 'BES2500BP', 1, 4, 1.43, 33, 5990000, 3000000, 'Xiaomi', 1595),
    (4, 'Apple Watch SE 2022 GPS 40mm', 'Apple S8', NULL, 32, 1.32, 16, 7490000, 4210000, 'Apple', 827),
    (4, 'Samsung Galaxy Watch5 40mm', 'Exynos W920', NULL, 16, 1.2, 0, 5990000, 2500000, 'Samsung', 773),
    (4, 'Xiaomi Redmi Watch 3 42.6mm', NULL, NULL, NULL, 1.75, 7, 2790000, 1220000, 'Xiaomi', 362),
    (4, 'Apple Watch Ultra LT 49mm', 'Apple S8', NULL, 32, 1.92, 16, 23990000, 18900000, 'Apple', 614);

INSERT INTO products(categoryid, product_name, discount, original_price, import_price, manufacturer, stock)
VALUES
	(5, 'PD 20W Anker PowerCore', 20, 1600000, 900000, 'Anker', 19944),
	(5, 'Chuột Không dây Logitech M190 ', 25, 390000, 170000, 'Logitech', 9842),
	(5, 'Chuột Gaming ASUS ROG Gladius III', 7, 1390000, 950000, 'Asus', 3783),
	(5, 'Bàn Phím Cơ Bluetooth Rapoo V700 - 8A', 6, 1490000, 1100000, 'Rapoo', 5589),
	(5, 'Bàn phím Gaming Asus ROG Strix Scope', 25, 3690000, 2100000, 'Asus', 5463),
	(5, 'Túi chống sốc Laptop 14 inch Zadez ZLC-820', 10, 290000,150000, 'Zadez', 2617),
	(5, 'Tai nghe Bluetooth TWS Xiaomi Redmi Buds 4 Lite', 12, 790000, 490000, 'Xiaomi', 2617),
	(5, 'Loa Bluetooth Rezo Home Series One', 22, 890000, 520000, 'Rezo', 3783);

INSERT INTO orders(customerid, payment_method)
VALUES
	(1, 'COD'),
	(2, 'COD'),
	(3, 'COD'),
	(4, 'bank transfer'),
	(5, 'bank transfer'),
	(6, 'bank transfer'),
	(6, 'bank transfer'),
	(6, 'bank transfer');
	
INSERT INTO orderlines(orderid, productid, quantity)
VALUES
	(1, 7, 3),
	(1, 21, 1),
	(2, 5, 2),
	(3, 3, 1),
	(4, 7, 1),
	(4, 6, 2),
	(5, 1, 1),
	(5, 6, 1),
	(5, 23, 1);
	
INSERT INTO cartlines(customerid, productid, quantity)
VALUES
	(1, 3, 1),
	(1, 2, 5),
	(2, 15, 2),
	(3, 13, 6),
	(4, 7, 7),
	(4, 16, 2),
	(5, 21, 2),
	(5, 5, 3),
	(5, 8, 4);

-------- UPDATE AND DELETE
DELETE FROM orderlines
WHERE orderid = 1 and productid = 7;

UPDATE orderlines
SET productid = 9, quantity = 5
WHERE orderid = 1 and productid = 21;

UPDATE orders
SET order_status = 'order placed'
WHERE order_status = 'new order';

UPDATE orders
SET order_status = 'in transit'
WHERE order_status = 'order placed';

UPDATE orders
SET order_status = 'delivered'
WHERE order_status = 'in transit';

-------- INSERT feedback
INSERT INTO feedback(customerid, productid, rate, comments, feedback_date, media1, media2)
VALUES 
    (1, 7, 5, 'san pham chat luong tot', '2023-04-28', 'image', NULL),
    (2, 5, 3, 'chat luong tam on', '2023-06-05', 'video', NULL),
    (5, 1, 1, 'san pham chat luong rat te, minh thuc su that vong khi nhan duoc hang', '2023-02-02', 'image', 'video'),
    (5, 6, 4, 'chat luong kha tot, tuy nhien hop dung san pham hoi bi mop', '2022-11-02', 'video','image' ),
    (4, 7, 5, 'san pham chat luong tot, dung nhu mo ta', '2023-01-12', 'image', 'video'),
    (5, 23, 5, 'san pham chat luong tot', '2023-01-11', NULL, NULL),
    (3, 3, 5, 'hang nhan duoc rat giong voi hinh anh minh hoa, chat luong thi can phai su dung 1 thoi gian roi moi biet duoc', '2022-12-21', 'video', NULL),
    (4, 4, 3, 'san pham khong duoc nhu mong doi', '2023-04-01', 'image', NULL),
    (4, 6, 5, 'chat luong tot, giao hang nhanh', '2023-04-11', 'image', NULL),
    (1, 9, 4, 'chat luong hang kha tot', '2023-03-01', NULL, NULL);
