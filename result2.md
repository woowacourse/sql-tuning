# 프로그래머별로 해당하는 병원 이름을 반환하세요. (covid.id, hospital.name)

hospital는 covid보다 데이터가 훨씬 적다. 드라이빙 테이블은 데이터가 적은 곳으로 해줘야  따라서 hospital를 기준으로 다시 쿼리를 작성해보았다.

```SQL
select c.id, c.programmer_id, h.id, h.name 
from hospital as h
	join (select id, programmer_id from covid) as c
	on h.id = c.programmer_id
where c.programmer_id is not null;
```

![image](https://user-images.githubusercontent.com/34594339/138636469-08e1ba94-d83b-4488-8ffe-0ec1bb1d2559.png)
![image](https://user-images.githubusercontent.com/34594339/138636308-63fd9b11-96f7-42d3-aa0c-20c5a4f65727.png)

드라이빙 테이블을 covid로 걸어준 쿼리(위)보다 드라이빙 테이블을을 hospital에 걸어준 쿼리(아래)가 훨씬 적은 rows를 가지는 것을 볼 수 있었다.


![image](https://user-images.githubusercontent.com/34594339/138636621-d3f14120-3ef3-4f17-b240-4716cde3b7ca.png)


###  👉 `0.015 sec` 에서 `0.0035sec`까지 개선


<br>
<br>
<br>

