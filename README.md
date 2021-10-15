# 🚀 조회 성능 개선하기

> 미션 요구사항은 A, B만 해당되어서 들어가기에 앞서는 안보셔도 되구 보셔도 되구 자유입니당 !!

## 목차
* [들어가기에 앞서](#들어가기에-앞서)
    * [1번](#실습-1번)
    * [2번](#실습-2번)
    * [3번](#실습-3번)
* [A. 쿼리 연습](#a-쿼리-연습)
  * [A1 - 쿼리 작성만으로 1s 이하로 반환한다.](#a1---쿼리-작성만으로-1s-이하로-반환한다)
  * [A2 - 인덱스 설정을 추가하여 50 ms 이하로 반환한다.](#a2---인덱스-설정을-추가하여-50-ms-이하로-반환한다)
* [B. 인덱스 설계](#b-인덱스-설계)
    * [B1 - Coding as a Hobby 와 같은 결과를 반환하세요.](#b1---coding-as-a-hobby-와-같은-결과를-반환하세요)
    * [B2 - 프로그래머별로 해당하는 병원 이름을 반환하세요.](#b2---프로그래머별로-해당하는-병원-이름을-반환하세요)
    * [B3 - 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요.](#b3---프로그래밍이-취미인-학생-혹은-주니어0-2년들이-다닌-병원-이름을-반환하고-userid-기준으로-정렬하세요)
    * [B4 - 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요.](#b4---서울대병원에-다닌-20대-india-환자들을-병원에-머문-기간별로-집계하세요)
    * [B5 - 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요.](#b5---서울대병원에-다닌-30대-환자들을-운동-횟수별로-집계하세요)

## 들어가기에 앞서
[실습사이트](https://www.w3schools.com/sql/trymysql.asp?filename=trysql_func_mysql_concat)에서 아래 문제를 해결해보자.

실습 관련 수행 과정은 [실습 과정 정리](./실습-과정-정리.md)에서 확인하실 수 있어요!

### 실습 1번
200개 이상 팔린 상품명과 그 수량을 수량 기준 내림차순으로 보여주세요.

```sql
select p.ProductID as '상품아이디', p.ProductName as '상품이름', sum(od.Quantity) as '총수량'
from Products p, OrderDetails od
where p.ProductID = od.ProductID
group by p.ProductID
having `총수량` >= 200
order by `총수량` desc;
```

### 실습 2번
많이 주문한 순으로 고객 리스트(ID, 고객명)를 구해주세요. (고객별 구매한 물품 총 갯수)

```sql
select c.CustomerID as '고객아이디', c.CustomerName as '고객이름', sum(od.Quantity) as '주문량'
from Orders o, Customers c, OrderDetails od
where o.CustomerID = c.CustomerID 
and o.OrderID = od.OrderID
group by c.CustomerID
order by `주문량` desc;
```

### 실습 3번
많은 돈을 지출한 순으로 고객 리스트를 구해주세요.

```sql
select c.CustomerID as '고객아이디', c.CustomerName as '고객이름', sum(od.Quantity*p.Price) as '지출금액'
from Orders o, Customers c, Products p, OrderDetails od
where o.CustomerID = c.CustomerID 
and o.OrderID = od.OrderID
and od.ProductID = p.ProductID
group by c.CustomerID
order by `지출금액` desc;
```

## A. 쿼리 연습
활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.  
(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)  
급여 테이블의 사용여부 필드는 사용하지 않습니다. 현재 근무중인지 여부는 종료일자 필드로 판단해주세요.

### A1 - 쿼리 작성만으로 1s 이하로 반환한다.

```sql
select 연봉상위5위.사원번호, 연봉상위5위.이름, 연봉상위5위.연봉, 연봉상위5위.직급명, 사원출입기록.입출입시간, 사원출입기록.지역, 사원출입기록.입출입구분
from 사원출입기록,
     (select 부서관리자.사원번호 as '사원번호', 사원.이름 as '이름', 급여.연봉 as '연봉', 직급.직급명 as '직급명'
      from 부서관리자
             inner join 부서 on 부서관리자.부서번호 = 부서.부서번호
             inner join 사원 on 부서관리자.사원번호 = 사원.사원번호
             inner join 급여 on 부서관리자.사원번호 = 급여.사원번호
             inner join 직급 on 부서관리자.사원번호 = 직급.사원번호
      where 부서.비고 = 'active'
        and 부서관리자.종료일자 >= curdate()
        and 급여.종료일자 >= curdate()
        and 직급.종료일자 >= curdate()
      order by `연봉` desc
        limit 5) as 연봉상위5위
where 입출입구분 = 'O'
  and 사원출입기록.사원번호 = 연봉상위5위.사원번호
order by 연봉 desc
;
```

* 실행 결과  
  <img src="/images/a1.png" width="900"/>

#### 쿼리에 대한 설명  
우선, 조회할 컬럼들을 먼저 살펴보았어요. 사원번호, 이름, 연봉, 직급명은 연봉 TOP 5 테이블을 만들며 뽑아낼 수 있는 값이라는 생각이 들었어요.
그래서 크게 연봉상위5위 테이블과, 사원출입기록 두 테이블을 가장 겉 쿼리에서 이용하기로 생각했어요.
내부 연봉상위5위 테이블을 만들기 위해 from 절에 서브쿼리를 사용했어요. 서브쿼린 내부에서는 모든 테이블과 연관관계를 가진 부서관리자 테이블에 각 테이블들을
inner join 하도록 구성했어요. 또한 종료일자를 오늘 날짜 이후로 설정함으로써 근무중임을 확인했다. 이때, `curdate()`와 `curtime()`, `now()`등을 사용할 수 있었는데,
각각의 차이는 다음과 같아요. 

|CURDATE|CURTIME|NOW|
|--------|------------|--------|
|2021-10-15|22:37:25|2021-10-15 22:37:25|

어차피 값에 시간은 포함되어있지 않기에 `curdate()`를 사용했어요. 이후 조건은 문제에 나온대로 설정했어요.


### A2 - 인덱스 설정을 추가하여 50 ms 이하로 반환한다.
```sql
CREATE INDEX I_사원번호 ON tuning.사원출입기록 (사원번호);
```

* 실행 결과  
  <img src="/images/a2.png" width="900"/>

* EC2에 DB를 올려놓고 연결해서 사용하다보니 네트워크에 따라서 Duration이 일정하지 않더라구요.. 😞  

#### 인덱스 설정에 대한 이유  
사원출입기록에 대한 Full Table Scan을 최적화하기위해 사원출입기록 테이블의 인덱스 정보를 확인했어요. (순번, 사원번호) 순으로는 인덱스가 걸려있었지만, 사원번호 단일로는 생성되어있지 않았어요. 조건절에서 사원번호를 사용하기에 사원번호 단일 인덱스를 생성해주었어요.

[질문]  
1. 입출입구분의 equal 연산자로 한번 거르고, 사원번호도 equal로 거르니 (입출입구분, 사원번호)와 같은 형태로 인덱스를 거는게 더 좋지 않을까? 라는 생각이
들었어요. 근데 별 차이가 없더라구요? 이유가 뭘까요?

## B. 인덱스 설계
* 조건  
  주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환

### B1 - Coding as a Hobby 와 같은 결과를 반환하세요.

* programmer.id에 PK 지정
* hobby에 index 지정
* filesort와 임시 테이블을 없애기 위해 `order by percentage desc` -> `order by null`로 변경해보았는데, 그렇게 많은 차이가 나지 않아 
  우선 Yes가 위에 나오도록 `order by percentage desc`를 유지했습니다.

```sql
CREATE INDEX I_hobby ON subway.programmer (hobby);

select hobby as 'coding as a hobby', round((count(id) * 100 / (select count(*) from subway.programmer)), 1) as 'percentage'
from subway.programmer
group by hobby
order by percentage desc;
```

* 실행 결과  

  <img src="/images/b1.png" width="900"/>

* Duration: 0.051sec  
#### 쿼리 및 인덱스에 대한 이유 + [질문]  
우선, 조건은 비교적 쉬운 편이기에 쿼리에 대한 이유는 패쓰할게요. 아마 대부분 동일할거라 생각해요. 이번에는 programmer.id에 PK를 지정하고, hobby에 인덱스를 추가로 지정해보았어요. 테이블의 프라이머리 키는 클러스터링의 기준이 되어요. 특히 InnoDB를 사용하기에 클러스터링 인덱스로 저장되는 테이블을 프라이머리 키 기반 검색이 빨라요. 그래서 서브쿼리에서 id를 활용하고 있기도 하고.. 등의 이유로 pk를 지정해줬어요. hobby에 추가 인덱스를 지정해준 이유는 group by 절에 인덱스를 적용해 인덱스 스캔이 일어나길 의도한 거였어요. 하지만 count(*)를 사용하고 있어서 그런지, 결국엔 full index scan이 일어나서 그렇게 효과는 없어보이네요.


### B2 - 프로그래머별로 해당하는 병원 이름을 반환하세요.
* (covid.id, hospital.name)  

```sql
select c.programmer_id as programmer, h.name as hospital_name
from subway.hospital h
       inner join subway.covid c on h.id = c.hospital_id
       inner join subway.programmer p on c.programmer_id = p.id;
```
* 실행 결과

  <img src="/images/b2.png" width="900"/>
  

* Duration: 0.023sec   

#### 쿼리 및 인덱스에 대한 이유
이번에는 인덱스를 따로 걸지 않았어요. pk로만 해결했습니다.

covid 행 총 수 -> 318325
hospital 행 총 수 -> 32
programmer 행 총 수 -> 98855

covid 테이블을 통해 programmer_id 및 hospital_id에 모두 접근할 수 있기에, covid를 기준으로 join을 수행했었어요. 하지만 더 적은 행의 개수를 가진 
hospital을 드라이빙 테이블로 설정해보았는데, 기존과 사실상 다름없는 결과가 나왔어요. 결국엔 3 테이블을 모두 inner join 하는 것이다 보니 동일하게 동작하는 것 같아요. (뇌피셜)
추가적으로 covid.programmer_id, covid.hospital_id에 fk를 설정해주었어요. 하지만 오히려 fk 설정 전 Unique Key Lookup을 도는 게 더 나은 것 같아서, fk는 우선 지웠어요. 사실 하면서도 옳은 방향으로 하고있는게 맞는지 의문이 드네요..

### B3 - 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요.
* (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)  

### B4 - 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요.
* (covid.Stay)  

### B5 - 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요.
* (user.Exercise)  
