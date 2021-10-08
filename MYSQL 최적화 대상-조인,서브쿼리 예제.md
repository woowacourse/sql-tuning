### 1. 200개 이상 팔린 상품명과 그 수량을 수량 기준 내림차순으로 보여주세요.

```sql
SELECT p.ProductID as '상품 아이디', p.ProductName as '상품이름', sum(od.Quantity) as '총수량'
FROM Products as p
JOIN OrderDetails as od on p.ProductID = od.ProductID
GROUP BY od.ProductID HAVING `총수량` >= 200
ORDER BY `총수량` desc;
```

![https://user-images.githubusercontent.com/48986787/136501357-065b8206-b39a-4841-85df-ebf7a6ae681e.png](https://user-images.githubusercontent.com/48986787/136501357-065b8206-b39a-4841-85df-ebf7a6ae681e.png)

### 2. 많이 주문한 순으로 고객 리스트(ID, 고객명)를 구해주세요. (고객별 구매한 물품 총 갯수)

```sql
SELECT ct.CustomerID as '고객아이디', ct.ContactName as '고객이름', sum(od.Quantity) as '주문량'
FROM Customers as ct
JOIN Orders as o on ct.CustomerID = o.CustomerID
JOIN OrderDetails as od on o.OrderID = od.OrderID
GROUP BY ct.CustomerID
ORDER BY `주문량` desc;
```

![https://user-images.githubusercontent.com/48986787/136502234-0a3028bd-30a8-4ded-8fbc-b204190a305e.png](https://user-images.githubusercontent.com/48986787/136502234-0a3028bd-30a8-4ded-8fbc-b204190a305e.png)

### 3. 많은 돈을 지출한 순으로 고객 리스트를 구해주세요.

```sql
SELECT ct.CustomerID as '고객아이디', ct.ContactName as '고객이름', sum(od.Quantity) * pd.Price as '지출금액'
FROM Customers as ct
JOIN Orders as o on ct.CustomerID = o.CustomerID
JOIN OrderDetails as od on o.OrderID = od.OrderID
JOIN Products as pd on od.ProductID = pd.ProductID
GROUP BY ct.CustomerID
ORDER BY `지출금액` desc
```

![https://user-images.githubusercontent.com/48986787/136504087-4422b4df-53ef-4491-bba8-2ac56b8409c7.png](https://user-images.githubusercontent.com/48986787/136504087-4422b4df-53ef-4491-bba8-2ac56b8409c7.png)