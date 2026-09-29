CREATE TABLE clientes (
    id_cliente INT PRIMARY KEY,
    nombre VARCHAR(50),
    segmento VARCHAR(20), -- 'retail', 'premium', 'empresa'
    fecha_alta DATE
);

CREATE TABLE transacciones (
    id_transaccion INT PRIMARY KEY,
    id_cliente INT REFERENCES clientes(id_cliente),
    fecha DATE,
    importe NUMERIC(10,2), -- positivo = ingreso, negativo = gasto/retirada
    tipo VARCHAR(20) -- 'transferencia', 'compra', 'retirada', 'ingreso'
);

INSERT INTO clientes VALUES
(1, 'Ana Ruiz', 'retail', '2019-03-15'),
(2, 'Bruno Soler', 'premium', '2021-07-01'),
(3, 'Carla Ibáñez', 'empresa', '2020-11-20'),
(4, 'David Roig', 'retail', '2022-01-10'),
(5, 'Elena Vidal', 'premium', '2018-05-30');

INSERT INTO transacciones VALUES
(101, 1, '2024-01-05', -200.00, 'compra'),
(102, 1, '2024-02-10', 1500.00, 'ingreso'),
(103, 2, '2024-01-20', -5000.00, 'retirada'),
(104, 2, '2024-03-01', 3000.00, 'ingreso'),
(105, 3, '2024-02-15', -12000.00, 'transferencia'),
(106, 3, '2024-03-10', 8000.00, 'ingreso'),
(107, 4, '2024-01-25', -50.00, 'compra'),
(108, 5, '2024-02-28', -7000.00, 'retirada'),
(109, 5, '2024-03-15', 200.00, 'ingreso'),
(110, 1, '2024-03-20', -300.00, 'compra');






-- ENCARGO 1
--Identificar clientes "de riesgo": aquellos cuyo importe neto del Q1 2024 sea inferior 
--a la media general de todos los clientes (no por segmento esta vez, la media de todos).

with netos as (
SELECT c.nombre, c.segmento,round(Sum(t.importe),0) as importe_neto  FROM clientes c
join transacciones t 
on c.id_cliente = t.id_cliente
where fecha between '2024-01-01' and '2024-03-31'
group by c.nombre, c.segmento),

 mediagen as (
select *, AVG(n.importe_neto) over() as media_general
from netos n
)

select m.nombre, m.segmento, m.importe_neto
from mediagen m
where m.importe_neto <  m.media_general;

--ENCARGO 2
--El director de banca personal quiere, para la reunión, saber quién es el cliente con el importe neto más alto de cada 
--segmento en el Q1 2024 (su "mejor cliente" por segmento, el que más ha ingresado o menos ha retirado).
--rank() o row number(), la unica diferencia es que rank() en caso de empate repite numero.

with netos as (
select c.nombre , c.segmento, round(Sum(t.importe),0) as importe_neto
from clientes c join transacciones t 
on c.id_cliente = t.id_cliente
where t.fecha between '2024-01-01' and '2024-03-31'
group by c.nombre, c.segmento),

ordenados as (select *, row_number() over (partition by n.segmento order by n.importe_neto desc  ) as orden
from netos n) 

select *
from ordenados
where orden = 1

;
------- MISMO ENCARGO, MAS COMPACTO------
with netos as (
select 
	c.nombre , c.segmento, round(Sum(t.importe),0) as importe_neto,
		row_number() over (partition by c.segmento order by SUM(t.importe) desc  ) as orden
from clientes c join transacciones t 
on c.id_cliente = t.id_cliente
where t.fecha between '2024-01-01' and '2024-03-31'
group by c.nombre, c.segmento)


select *
from netos
where orden = 1
;

--ENCARGO 3
--El director quiere una lista de clientes que no han hecho ninguna transacción de tipo 'ingreso' en todo el Q1 2024.

select c.nombre, c.segmento
from clientes c 
where not exists (select 1 
from transacciones t2
where t2.id_cliente = c.id_cliente and 
t2.tipo = 'ingreso' and
t2.fecha between '2024-01-01' and '2024-03-31'
);

select c.nombre, c.segmento
from clientes c join transacciones t
on c.id_cliente = t.id_cliente
where  exists (select 1 				
from transacciones t2						
where t2.id_cliente = c.id_cliente and 
t2.tipo = 'ingreso' and
t2.fecha between '2024-01-01' and '2024-03-31'
);

--ENCARGO 4
--Para cada cliente, en el Q1 2024, necesita:
--Nombre, segmento e importe neto.
--Su puesto (RANK(), no ROW_NUMBER() esta vez) dentro de su segmento, ordenado de mejor a peor importe neto.
--Una columna adicional que diga 'alerta' si el cliente no ha hecho ninguna transacción de tipo 'ingreso' en el Q1, y 'ok' si sí la ha hecho."

select c.nombre, c.segmento, SUM(t.importe) as importe_neto,
rank() over(partition by c.segmento order by sum(t.importe) desc ) as orden,

	case
		when exists (
			select 1
			from transacciones t2
			where t2.id_cliente = c.id_cliente and
				t2.tipo = 'ingreso'and
				t2.fecha between '2024-01-01' and '2024-03-31'

		
		) then 'Ok'
		else 'Alerta'
	end as Alerta
	
from clientes c join transacciones t 
on c.id_cliente = t.id_cliente
group by c.id_cliente, c.nombre, c.segmento;

--ENCARGO 5
--El departamento de marketing quiere contactar a clientes activos, pero esta vez con dos condiciones a la vez: 3 o más transacciones en total, 
--Y que su importe neto total (todas las fechas) sea positivo.
--Necesitan nombre, segmento, número de transacciones e importe neto total.


select c.nombre, c.segmento, SUM(importe) as importe_neto,
count(*) as Nº_transacciones
from clientes c join transacciones t 
on c.id_cliente = t.id_cliente 
group by c.nombre, c.segmento, c.id_cliente 
having SUM(t.importe)> 0 and count(*) >= 3

;

--ENCARGO 6
--Quieres saber quién es el segundo mejor cliente de cada segmento por importe neto del Q1 2024 (no el primero, el segundo).
-- Nombre, segmento, importe neto y puesto.

select *
from ( select c.nombre, c.segmento, SUM(t.importe) as importe_neto,
	rank() over(partition by c.segmento order by sum(t.importe) desc) as ranking
	from clientes c join transacciones t 
	on c.id_cliente = t.id_cliente
	group by c.nombre, c.segmento)
where ranking = 2

	;
	
	
--ENCARGO 7
--El ejercicio 3, recordatorio: clientes que en el Q1 2024 hicieron al menos una retirada de tipo 'retirada', 
--pero que nunca hicieron ningún 'ingreso' en ese mismo periodo. Nombre y segmento.

select c.nombre, c.segmento
from clientes c 
where exists (select 1
	from transacciones t 
	where t.id_cliente = c.id_cliente and t.tipo = 'retirada' and t.fecha between '2024-01-01' and '2024-03-31') 
	and 
	not exists ( select 1
	from transacciones t 
	where t.id_cliente = c.id_cliente and t.tipo = 'ingreso' and t.fecha between '2024-01-01' and '2024-03-31')
group by c.nombre, c.segmento;


