-- Этап 1. Создание и заполнение БД

create schema raw_data;
create table raw_data.sales (
     id varchar primary key,
     auto varchar,
     gasoline_consumption varchar,
     price varchar,
     date varchar,
     person varchar,
     phone varchar,
     discount varchar,
     brand_origin varchar
);

create schema car_shop;

create table car_shop.client (
     client_id serial primary key,
     name varchar not null,
     phone varchar unique not null); -- телефон должен быть уникальным

create table car_shop.brand (
     brand_id serial primary key,
     brand_name varchar unique not null, -- бренды не должны повторяться
     brand_origin varchar not null 
);

create table car_shop.color (
    color_id serial primary key,
    color_name varchar unique not null -- цвет не должен повторяться
);

create table car_shop.car(
    car_id serial primary key,
    brand_id int references car_shop.brand(brand_id), -- ссылка на бренд
    model varchar not null, 
    gasoline_consumption numeric (3,1) -- потому что не расход не может быть трехзначным числом
);

create table car_shop.sales (
    sale_id serial primary key,
    client_id integer references car_shop.client(client_id) not null, -- ссылка на клиента
    car_id integer references car_shop.car(car_id) not null, -- ссылка на машину        
    color_id integer references car_shop.color(color_id), -- ссылка на цвет           
    date date not null, -- дата продажи                                             
    price numeric(9,2) not null check (price > 0), -- цена с проверкой, что она не может быть отрицательным числом, также нумерик потому что может содержать только сотые поэтому 2, и не может быть больше семизначной суммы, и у нумерик повышенная точность при работе с дробными числами    
    discount integer default 0 check (discount >= 0 and discount <= 100) -- ссылка в процентах, по умолчанию будет 0, и так же скидка не может быть отрицательной и не можнт быть больше 100 
);

insert into car_shop.color (color_name)
select distinct trim(split_part(auto, ',', 2))
from raw_data.sales s
where auto is not null and split_part(auto, ',', 2) <> '';

insert into car_shop.brand (brand_name, brand_origin)
select distinct 
    split_part(trim(split_part(auto, ', ', 1)), ' ', 1) AS brand_name,
    brand_origin
from raw_data.sales
where auto is not null;
     
insert into car_shop.car (brand_id, model, gasoline_consumption)
select distinct 
    b.brand_id,
    trim(replace(split_part(s.auto, ', ', 1), b.brand_name, '')) as model,
    case 
        when s.gasoline_consumption = 'null' or s.gasoline_consumption = '' then null
        else s.gasoline_consumption::numeric(3,1)
    end as gasoline_consumption
from raw_data.sales s
join car_shop.brand b 
  on b.brand_name = split_part(trim(split_part(s.auto, ', ', 1)), ' ', 1)
where s.auto is not null;

insert into car_shop.sales (client_id, car_id, color_id, date, price, discount)
select 
     cl.client_id,
     c.car_id,
     co.color_id,
     s.date::date,
     s.price::numeric(9,2),
     case 
     	when s.discount = 'null' or s.discount = '' then 0
     	else s.discount::integer
     	end as discount
from raw_data.sales s 
join car_shop.client cl on cl.name = s.person and cl.phone = s.phone 
join car_shop.brand b on b.brand_name = split_part(trim(split_part(s.auto, ', ', 1)), ' ', 1)
join car_shop.car c on c.brand_id = b.brand_id and c.model = trim(replace(split_part(s.auto, ', ', 1), b.brand_name, ''))
left join car_shop.color co on co.color_name = trim(split_part(s.auto, ', ', 2))
where s.auto is not null;
     
truncate table car_shop.client cascade;

insert into car_shop.client (name, phone)
select distinct person_name, phone 
from raw_data.sales 
where person_name is not null;

insert into car_shop.sales (client_id, car_id, color_id, date, price, discount)
select 
     cl.client_id,
     c.car_id,
     co.color_id,
     s.date::date,
     s.price::numeric(9,2),
     case 
     	when s.discount = 'null' or s.discount = '' then 0
     	else s.discount::integer
     	end as discount
from raw_data.sales s 
join car_shop.client cl on cl.name = s.person_name and cl.phone = s.phone 
join car_shop.brand b on b.brand_name = split_part(trim(split_part(s.auto, ', ', 1)), ' ', 1)
join car_shop.car c on c.brand_id = b.brand_id and c.model = trim(replace(split_part(s.auto, ', ', 1), b.brand_name, ''))
left join car_shop.color co on co.color_name = trim(split_part(s.auto, ', ', 2))
where s.auto is not null;

-- Этап 2. Создание выборок

---- Задание 1. Напишите запрос, который выведет процент моделей машин, у которых нет параметра `gasoline_consumption`.

select 
    (count(case when gasoline_consumption is null then 1 end) *100.0 / count(*)) as nulls_percentage_gasoline_consumption
from car_shop.car c;

---- Задание 2. Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.

select brand_name as brand_name,
       extract(year from s.date) as year,
       round(avg(s.price * (1 - s.discount / 100.0)), 2) as price_avg
from car_shop.sales s
join car_shop.car c using(car_id)
join car_shop.brand b using(brand_id)
group by brand_name, extract(year from s.date)
order by brand_name, year;

---- Задание 3. Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.

select 
     extract(month from s.date) as month,
     extract(year from s.date) as  year, 
     round(avg(s.price *(1-s.discount/ 100.0)), 2) as price_avg
from car_shop.sales s 
where extract(year from s.date) = 2022
group by month, year
order by month

---- Задание 4. Напишите запрос, который выведет список купленных машин у каждого пользователя.

select 
     cl.name as person,
     string_agg(b.brand_name || ' ' || c.model, ', ') as cars
from car_shop.client cl 
join car_shop.sales s using(client_id)
join car_shop.car c using(car_id)
join car_shop.brand b using(brand_id)
group by cl.name
order by person;

---- Задание 5. Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки. Цена в колонке price дана с учётом скидки.

select 
    b.brand_origin,
    round(max(s.price / (1 - s.discount / 100.0)), 2) as price_max, 
    round(min(s.price / (1 - s.discount / 100.0)), 2) as price_min -- тут округлил до 2 знаков после запятов потому что без округления там такое число = 11134.25925925925925925926
from car_shop.sales s 
join car_shop.car c using(car_id)
join car_shop.brand b using(brand_id)
where b.brand_origin is not null 
  and b.brand_origin != 'null'  
group by b.brand_origin;

---- Задание 6. Напишите запрос, который покажет количество всех пользователей из США.

select count(client_id) as person_from_usa_count
from car_shop.client c
where phone like '+1%';
