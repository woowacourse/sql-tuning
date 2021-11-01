# 🚀 조회 성능 개선하기

## A. 쿼리 연습

### * 실습환경 세팅

```sh
$ docker run -d -p 23306:3306 brainbackdoor/data-tuning:0.0.1
```
- [workbench](https://www.mysql.com/products/workbench/)를 설치한 후 localhost:23306 (ID : user, PW : password) 로 접속합니다.

<div style="line-height:1em"><br style="clear:both" ></div>

> 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.
(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)

1. 쿼리 작성만으로 1s 이하로 반환한다.
```sql
SELECT TOP5.사원번호, TOP5.이름, TOP5.연봉, TOP5.직급명, 사원출입기록.입출입시간, 사원출입기록.지역, 사원출입기록.입출입구분 
FROM 사원출입기록
inner join 
  (SELECT 부서관리자.사원번호, 사원.이름, 급여.연봉, 직급.직급명 
  FROM 부서관리자
  inner join 부서 on 부서관리자.부서번호=부서.부서번호 
  inner join 급여 on 부서관리자.사원번호=급여.사원번호
  inner join 직급 on 부서관리자.사원번호=직급.사원번호
  inner join 사원 on 부서관리자.사원번호=사원.사원번호
  where 부서관리자.종료일자='9999-01-01' AND 급여.종료일자='9999-01-01' AND 직급.종료일자='9999-01-01' AND 부서.비고='ACTIVE'
  order by 급여.연봉 desc limit 5) as TOP5 
on 사원출입기록.사원번호 = TOP5.사원번호
where 사원출입기록.입출입구분='O'
order by TOP5.연봉 DESC;
```
- 결과: 0.325sec
![Screenshot from 2021-10-18 01-42-08](https://user-images.githubusercontent.com/49307266/137636777-98d9c6a5-d406-4942-a39f-494f68374eec.png)

2. 인덱스 설정을 추가하여 50 ms 이하로 반환한다.

- 문제 분석 : 사원출입기록에서 테이블 FULL SCAN에서 너무 많은 비용 발생 -> 사원번호로 index 추가
![db-tuning](https://user-images.githubusercontent.com/49307266/137636866-a7fb7fb4-0da8-45b4-9614-8d0e861fcefe.png)
![Screenshot from 2021-10-18 01-48-59](https://user-images.githubusercontent.com/49307266/137637006-4fc7a5d2-8ffd-46af-864b-8be7ea1b9464.png)

- index 추가
```
CREATE INDEX `idx_사원출입기록_사원번호`  ON `tuning`.`사원출입기록` (사원번호) COMMENT '' ALGORITHM DEFAULT LOCK DEFAULT
```

- 결과: 0.0015sec
![Screenshot from 2021-10-18 01-51-20](https://user-images.githubusercontent.com/49307266/137637091-c28670b7-72e2-4706-8cd5-636b52168737.png)

<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>


## B. 인덱스 설계

### * 실습환경 세팅

```sh
$ docker run -d -p 13306:3306 brainbackdoor/data-subway:0.0.2
```
- [workbench](https://www.mysql.com/products/workbench/)를 설치한 후 localhost:13306 (ID : root, PW : masterpw) 로 접속합니다.

<div style="line-height:1em"><br style="clear:both" ></div>

### * 요구사항: 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환
0. primary key 설정
  covid, hospital, programmer의 pk설정이 안되어 있기에, id를 pk로 설정해줌

1. [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.
```sql
SELECT hobby, 100 * count(*) / (SELECT count(*) FROM programmer) as ratio 
FROM programmer 
group by hobby;
```

- hobby index 추가 (기존 0.352Sec -> 0.076sec )
![Screenshot from 2021-10-18 01-59-56](https://user-images.githubusercontent.com/49307266/137637349-112d304a-1b84-4bad-9104-8804cc993556.png)

2. 각 프로그래머별로 해당하는 병원 이름을 반환하세요.  (covid.id, hospital.name)
```sql
SELECT p.id, h.name
FROM programmer as p
inner join covid as c on p.id=c.programmer_id
inner join hospital as h on c.hospital_id=h.id;
```

- 문제 분석 : covid table full scan을 진행하고 있음 (0.0044sec) -> covid.hospital_id, covid.programmer_id index 조합 도전
![Screenshot from 2021-11-01 20-46-58](https://user-images.githubusercontent.com/49307266/139666898-e8217126-89db-484e-9866-00f419d5f8fa.png)

- 1. covid.hospital_id, covid.programmer_id 각각 index
  cardinarity 높은 programmer_id index를 사용하여 진행.
![Screenshot from 2021-11-01 21-08-29](https://user-images.githubusercontent.com/49307266/139669196-31f626ce-7d7c-46ee-99b3-f720278849e9.png)
- 2. (covid.hospital_id, covid.programmer_id) index -> hospital부터 조회하도록 수정됨. 하지만 programmer_id cardinarity가 높아서 오히려 비효율적
![Screenshot from 2021-11-01 21-17-12](https://user-images.githubusercontent.com/49307266/139670112-633fb4eb-9c89-405b-9ed5-43d5eae0aba2.png)
- 3. (covid.programmer_id, covid.hopspital_id) index -> 가장 빠른 성능을 보임.
![Screenshot from 2021-11-01 21-13-59](https://user-images.githubusercontent.com/49307266/139669761-8c13eebc-a81b-40f6-9001-afd4c995670a.png)

- 결과 (기존 0.0044sec -> 0.0034sec) : 큰 차이를 만들어 내지는 못함. 당연히 3번의 id만을 이용한 조회가 빠를 것이라 생각했음. 이유를 유추해보면, covid 테이블의 어느 이후에 값들은 모두 null로 들어가 있었기 때문에, 모두 pass 한 것으로 보임!


3. 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)

```sql
SELECT p.id, h.name, p.hobby, p.dev_type, p.years_coding
FROM programmer as p
inner join covid as c on p.id=c.programmer_id
inner join hospital as h on c.hospital_id=h.id
where p.hobby='yes' or p.years_coding='0-2 years';
```

- 결과 (0.011sec) : hobby index 보다는 full scan이 효율적인 것으로 보임(카디널리티가 낮기 때문에, count(*)인 경우정도에만 사용될 것으로 생각). 2번에서 cvoid의 programmer_id index만으로 충분한 것으로 보임
- ![Screenshot from 2021-10-18 02-30-22](https://user-images.githubusercontent.com/49307266/137638324-54997a35-4971-495d-b186-8d8e52f11a25.png)


4. 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)
```sql
SELECT c.stay, count(*)
FROM programmer as p
inner join member as m on p.member_id=m.id
inner join covid as c on p.id=c.programmer_id
inner join hospital as h on c.hospital_id=h.id
where p.country='India' and 20 <= m.age and m.age < 30 and h.name='서울대병원'
group by stay;
```
- 문제 분석(0.274sec)
![Screenshot from 2021-10-18 02-44-06](https://user-images.githubusercontent.com/49307266/137638718-c2d96b05-ffb8-4b55-a598-a5c370dd19bd.png)

- programmer -> country index 추가
![Screenshot from 2021-10-18 02-43-20](https://user-images.githubusercontent.com/49307266/137638730-f8799497-8ba1-4710-a91c-8b5d32cbaa64.png)

- member -> age index 추가
![Screenshot from 2021-10-18 02-45-57](https://user-images.githubusercontent.com/49307266/137638797-f2e0bce6-0382-47eb-8048-830f9800eca5.png)

- hospital -> name index 추가 
![Screenshot from 2021-10-18 03-24-35](https://user-images.githubusercontent.com/49307266/137640085-c7d705b1-747f-4f35-a26d-1615b46f8880.png)

- programmer -> id index 추가, 당연히 있을 줄 알았는데, 존재 하지 않았어서 추가. 100ms 부근으로 쿼리 결과 나옴
![Screenshot from 2021-10-18 03-37-32](https://user-images.githubusercontent.com/49307266/137640469-d698c7c1-945a-453e-a1e3-8ca395d10af8.png)


5. 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)
```sql
SELECT p.exercise, count(*)
FROM covid as c
inner join member as m on c.member_id=m.id
inner join programmer as p on c.programmer_id=p.id
inner join hospital as h on c.hospital_id=h.id
where 30 <= m.age and m.age < 40 and h.name='서울대병원'
group by p.exercise;
```

- 결과 0.09sec
![Screenshot from 2021-10-18 03-38-04](https://user-images.githubusercontent.com/49307266/137640486-3a82a622-f768-4d06-bf68-82e4546221c0.png)


<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>

## C. 프로젝트 요구사항

### a. 페이징 쿼리를 적용 

### b. Replication 적용 
