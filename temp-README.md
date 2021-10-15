// 제출 전 임시 README
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

### A2 - 인덱스 설정을 추가하여 50 ms 이하로 반환한다.
```sql
CREATE INDEX I_사원번호 ON tuning.사원출입기록 (사원번호);
```

* 실행 결과  
  <img src="/images/a2.png" width="900"/>

* EC2에 DB를 올려놓고 연결해서 사용하다보니 네트워크에 따라서 Duration이 일정하지 않더라구요.. 😞

[질문]  
1. 입출입구분의 equal 연산자로 한번 거르고, 사원번호도 equal로 거르니 (입출입구분, 사원번호)와 같은 형태로 인덱스를 거는게 더 좋지 않을까? 라는 생각이
들었어요. 근데 별 차이가 없더라구요? 이유가 뭘까요?

## B. 인덱스 설계
* 조건  
  주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환

### B1 - Coding as a Hobby 와 같은 결과를 반환하세요.


### B2 - 프로그래머별로 해당하는 병원 이름을 반환하세요.
* (covid.id, hospital.name)  


### B3 - 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요.
* (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)  

### B4 - 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요.
* (covid.Stay)  

### B5 - 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요.
* (user.Exercise)  
