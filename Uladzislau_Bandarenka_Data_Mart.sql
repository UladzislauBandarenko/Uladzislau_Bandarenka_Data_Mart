--1) create a fact table: factsupplierpurchases
create table factsupplierpurchases (
    purchaseid serial primary key,
    supplierid int,
    totalpurchaseamount decimal,
    purchasedate date,
    numberofproducts int,
    foreign key (supplierid) references dimsupplier(supplierid)
);

-- populate the factsupplierpurchases table with data aggregated from the staging tables
insert into factsupplierpurchases (supplierid, totalpurchaseamount, purchasedate, numberofproducts)
select 
    p.supplierid, 
    sum(od.unitprice * od.qty) as totalpurchaseamount, 
    current_date as purchasedate, 
    count(distinct od.productid) as numberofproducts
from staging_order_details od
join staging_products p on od.productid = p.productid
group by p.supplierid;

--- supplier spending analysis
select
    s.companyname,
    sum(fsp.totalpurchaseamount) as totalspend,
    extract(year from fsp.purchasedate) as year,
    extract(month from fsp.purchasedate) as month
from factsupplierpurchases fsp
join dimsupplier s on fsp.supplierid = s.supplierid
group by s.companyname, year, month
order by totalspend desc;

--product cost breakdown by supplier
select
    s.companyname,
    p.productname,
    avg(od.unitprice) as averageunitprice,
    sum(od.qty) as totalquantitypurchased,
    sum(od.unitprice * od.qty) as totalspend
from staging_order_details od
join staging_products p on od.productid = p.productid
join dimsupplier s on p.supplierid = s.supplierid
group by s.companyname, p.productname
order by s.companyname, totalspend desc;

--top five products by total purchases per supplier
select
    s.companyname,
    p.productname,
    sum(od.unitprice * od.qty) as totalspend
from staging_order_details od
join staging_products p on od.productid = p.productid
join dimsupplier s on p.supplierid = s.supplierid
group by s.companyname, p.productname
order by s.companyname, totalspend desc
limit 5;


--supplier performance report не работает 

--supplier reliability score report не работает 

--2) create a fact table: factproductsales
create table factproductsales (
    factsalesid serial primary key,
    dateid int,
    productid int,
    quantitysold int,
    totalsales decimal(10,2),
    foreign key (dateid) references dimdate(dateid),
    foreign key (productid) references dimproduct(productid)
);

-- insert into factproductsales table:
insert into factproductsales (dateid, productid, quantitysold, totalsales)
select 
    (select dateid from dimdate where date = s.orderdate) as dateid,
    p.productid, 
    sod.qty, 
    (sod.qty * sod.unitprice) as totalsales
from staging_order_details sod
join staging_orders s on sod.orderid = s.orderid
join staging_products p on sod.productid = p.productid;

--top-selling products
select 
    p.productname,
    sum(fps.quantitysold) as totalquantitysold,
    sum(fps.totalsales) as totalrevenue
from 
    factproductsales fps
join dimproduct p on fps.productid = p.productid
group by p.productname
order by totalrevenue desc
limit 5;

--products below reorder не работает 


-- sales trends by product category:
select 
    c.categoryname, 
    extract(year from d.date) as year,
    extract(month from d.date) as month,
    sum(fps.quantitysold) as totalquantitysold,
    sum(fps.totalsales) as totalrevenue
from 
    factproductsales fps
join dimproduct p on fps.productid = p.productid
join dimcategory c on p.categoryid = c.categoryid
join dimdate d on fps.dateid = d.dateid
group by c.categoryname, year, month, d.date
order by year, month, totalrevenue desc;

--inventory valuation
select 
    p.productname,
    p.unitsinstock,
    p.unitprice,
    (p.unitsinstock * p.unitprice) as inventoryvalue
from 
    dimproduct p
order by inventoryvalue desc;	
	
--supplier performance based on product sales
select 
    s.companyname,
    count(distinct fps.factsalesid) as numberofsalestransactions,
    sum(fps.quantitysold) as totalproductssold,
    sum(fps.totalsales) as totalrevenuegenerated
from 
    factproductsales fps
join dimproduct p on fps.productid = p.productid
join dimsupplier s on p.supplierid = s.supplierid
group by s.companyname
order by totalrevenuegenerated desc

	
		
-- 3) не работает 	

--4) all tables were created in the first task and aggregate sales by month and category
select d.month, d.year, c.categoryname, sum(fs.totalamount) as totalsales
from factsales fs
join dimdate d on fs.dateid = d.dateid
join dimcategory c on fs.categoryid = c.categoryid
group by d.month, d.year, c.categoryname
order by d.year, d.month, totalsales desc;	
	

-- top-selling products per quarter
select d.quarter, d.year, p.productname, sum(fs.quantitysold) as totalquantitysold
from factsales fs
join dimdate d on fs.dateid = d.dateid
join dimproduct p on fs.productid = p.productid
group by d.quarter, d.year, p.productname
order by d.year, d.quarter, totalquantitysold desc
limit 5;
				
-- customer sales overview
select cu.companyname, sum(fs.totalamount) as totalspent, count(distinct fs.salesid) as transactionscount
from factsales fs
join dimcustomer cu on fs.customerid = cu.customerid
group by cu.companyname
order by totalspent desc;
				
--sales performance by employee	
select e.firstname, e.lastname, count(fs.salesid) as numberofsales, sum(fs.totalamount) as totalsales
from factsales fs
join dimemployee e on fs.employeeid = e.employeeid
group by e.firstname, e.lastname
order by totalsales desc;	
					
--monthly sales growth rate	
with monthlysales as (
select
        d.year,
        d.month,
        sum(fs.totalamount) as totalsales
    from factsales fs
    join dimdate d on fs.dateid = d.dateid
    group by d.year, d.month
),
monthlygrowth as (
    select
        year,
        month,
        totalsales,
        lag(totalsales) over (order by year, month) as previousmonthsales,
        (totalsales - lag(totalsales) over (order by year, month)) / lag(totalsales) over (order by year, month) as growthrate
    from monthlysales
)
select * from monthlygrowth;