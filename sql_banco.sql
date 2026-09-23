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


--ENCARGO 1--
SELECT c.nombre, c.segmento,round(Sum(t.importe),0) as importe_neto  FROM clientes c
join transacciones t 
on c.id_cliente = t.id_cliente
where fecha between '2024-01-01' and '2024-03-31'
group by c.nombre, c.segmento
having  SUM(t.importe) < 0
order by importe_neto;

--RETO EXTRA--  EXPLICACION -->La window function actúa sobre el resultado ya agrupado, no sobre las filas originales de transacciones. 
--Por eso, dentro del OVER, no puedes usar t.importe a pelo: tienes que decirle sobre qué agregado calcular la media.

select c.nombre, c.segmento,round(Sum(t.importe),0) as importe_neto, 
AVG(SUM(t.importe)) over(partition by c.segmento) as Media_Segmento
FROM clientes c
join transacciones t 
on c.id_cliente = t.id_cliente
where fecha between '2024-01-01' and '2024-03-31'
group by c.nombre, c.segmento;
--Tiene sentido en cuanto ves el orden en que Postgres construye el resultado:

--Primero resuelve FROM/JOIN, WHERE y GROUP BY. Esto te deja una tabla intermedia con una fila por cliente, y en esa fila ya tienes SUM(t.importe) calculado como un valor fijo (el importe neto de ese cliente).
--Después, las window functions se aplican sobre esa tabla ya agrupada, fila a fila, sin volver a colapsarla. AVG(SUM(t.importe)) OVER (PARTITION BY c.segmento) significa: "toma el valor de SUM(t.importe) de cada fila (que ya es un neto por cliente), agrúpalas mentalmente por segmento, y calcula la media de esos netos — pero sin fusionar las filas".


-- ENCARGO 2 
--Quiere identificar clientes "de riesgo": aquellos cuyo importe neto del Q1 2024 sea inferior 
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

--ENCARGO 3
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
from netos n) --esto podria ir en la primera etapa

select *
from ordenados
where orden = 1

;
------- MISMO ENCARGO, MAS COMPACTO!!!------
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
where orden = 1 -- where se ejecuta de lo primero, entonces lo tienes que poner en otra consulta, porque si no, cuando se ejecute, orden no estara creado
;

--ENCARGO 4 
--El director quiere una lista de clientes que no han hecho ninguna transacción de tipo 'ingreso' en todo el Q1 2024

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
where  exists (select 1 				-- Esta está mal, al hacer el join que es innecesario, cada cliente va a aparecer
from transacciones t2						-- tantas veces como filas en las que cumpla la condicion.
where t2.id_cliente = c.id_cliente and 
t2.tipo = 'ingreso' and
t2.fecha between '2024-01-01' and '2024-03-31'
);


