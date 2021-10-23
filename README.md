# 🚀 조회 성능 개선하기

## A. 쿼리 연습

> 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.
(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)

1. 쿼리 작성만으로 1s 이하로 반환한다. 

### 작성한 쿼리 

```MySQL
SELECT `고액연봉자`.`사원번호`, `사원`.`이름`, `고액연봉자`.`연봉`, `고액연봉자`.`직급명`, `사원출입기록`.`입출입시간`, `사원출입기록`.`입출입시간`
FROM (SELECT `현재_근무중인_부서관리자`.`사원번호`, `급여`.`연봉`, `관리자_직급`.`직급명`
	FROM (SELECT * FROM tuning.`부서관리자` WHERE `종료일자` > NOW()) AS `현재_근무중인_부서관리자`
	JOIN (SELECT * FROM tuning.`부서` WHERE `비고` = 'active') AS `활동중_부서` ON `현재_근무중인_부서관리자`.`부서번호` = `활동중_부서`.`부서번호`
	JOIN (SELECT * FROM tuning.`급여` WHERE `종료일자` > NOW()) AS `급여` ON `현재_근무중인_부서관리자`.`사원번호` = `급여`.`사원번호` 
    JOIN (SELECT * FROM tuning.`직급` WHERE `직급명` = "Manager") AS `관리자_직급` ON `관리자_직급`.`사원번호` = `현재_근무중인_부서관리자`.`사원번호`
	ORDER BY `급여`.`연봉` DESC
	LIMIT 5) AS `고액연봉자` 
JOIN tuning.`사원` ON `사원`.`사원번호` = `고액연봉자`.`사원번호`
JOIN tuning.`사원출입기록` ON `고액연봉자`.`사원번호` = `사원출입기록`.`사원번호`
WHERE `사원출입기록`.`입출입구분` = 'O' 
ORDER BY `고액연봉자`.`연봉` DESC
```

Duration: **0.374 ms**

### 조회 결과 
![image](https://user-images.githubusercontent.com/47850258/138558699-2050ff7b-a93c-4d3f-b545-6b83205b8196.png)


2. 인덱스 설정을 추가하여 50ms 이하로 반환한다. 

1번 내용 EXPLAIN한 결과 
![image](https://user-images.githubusercontent.com/47850258/138558787-b52d1e2f-9171-4b66-a890-be5eb0986e18.png)

```
> Row 갯수                      추가한 인덱스 
직급: 443308 개       —> 직급명 
사원출입기록: 660000 
사원: 300024
부서사원매핑: 331603
부서관리자: 24 
부서: 9
급여: 2844047 
``` 

부서는 9개의 Row 밖에 없기 때문에 Full Table Scan이 성능상에 문제를 일으키지 않는다. 
`사원 출입 기록`이 660,000개나 있기 때문에 이 테이블에 index를 적절히 걸어주면 성능 개선을 할 수 있을 것 같다고 추측! 

![image](https://user-images.githubusercontent.com/47850258/138559096-e5b965b3-e1e8-4eb7-9a91-95e3a6188674.png)
Where 조건절에서 사용하고있는 `사원번호`를 index로 추가하고 조회

조회 결과: *0.0024s*


## B. 인덱스 설계

### * 실습환경 세팅

```sh
$ docker run -d -p 13306:3306 brainbackdoor/data-subway:0.0.2
```
- [workbench](https://www.mysql.com/products/workbench/)를 설치한 후 localhost:13306 (ID : root, PW : masterpw) 로 접속합니다.

<div style="line-height:1em"><br style="clear:both" ></div>

### * 요구사항

- [ ] 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환

    - [x] [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.


### 작성한 쿼리 (programmer 테이블에 hobby를 index 컬럼으로 추가함)
```MySQL
SELECT ROUND((SELECT COUNT(*) 
	FROM subway.programmer
	WHERE hobby = 'Yes')/COUNT(*) * 100, 1) AS "YES", 
    ROUND((SELECT COUNT(*) 
	FROM subway.programmer
	WHERE hobby = 'No')/COUNT(*) * 100, 1) AS "NO"
FROM subway.programmer;
```

### 조회 결과 
![image](https://user-images.githubusercontent.com/47850258/138560306-ef9dfb72-a5f7-4787-92b6-3b696a8ba2b6.png)

Duraion: **0.094s**

    - [x] 각 프로그래머별로 해당하는 병원 이름을 반환하세요.  (covid.id, hospital.name)
    
### 1차 시도 
![image](https://user-images.githubusercontent.com/47850258/138562697-2d67d51f-af33-4779-8299-51fb11c3b45c.png)

사실 조회하는 두 개의 테이블 모두 `Full Scan Table`을 함에도 불구하고 거뜬하게 조건을 만족... (학습의 목적이 없는 것 같아서 조금 더 개선해기로 함) 

### 2차 시도 

```
#조회하는 두 테이블의 총 Row 갯수 
Covid : 318325
Hospital:  32
```

> Hospital은 Full Table Scan해도 무방, Covid의 성능개선이 시급!
현재 Covid 테이블은 index column이 없다! 
일단 id 컬럼부터 Index를 걸어봤다. 

![image](https://user-images.githubusercontent.com/47850258/138562841-f12ffd61-a13e-4959-890b-02347e9a772f.png)

> 하지만 효과는 미약했다!

### 3차 시도 

Covid의 Where 절의 조건으로 걸리는 programmer_id를 index column으로 지정했다! 

![image](https://user-images.githubusercontent.com/47850258/138562927-bd4611c5-7082-4a1a-ba04-561564f804d5.png)
음... 전혀 효과가 없어서 왜그런가 싶어서 EXPLAIN으로 확인했더니 Full table scan 하고있다.. 🤔

![image](https://user-images.githubusercontent.com/47850258/138562953-710ad5fb-7547-4b75-92d5-563a74cf07b9.png)

### 4차 시도
![image](https://user-images.githubusercontent.com/47850258/138562984-098cbf90-e777-423b-967c-400e2c4d03d3.png)

원래부터 워낙 빠르게 동작하다보니 뭔가 Dynamic한 변화는 없다😢 
Full Table Scan의 늪에서 벗어났다!!! 

해결방법: 단순히 covid 테이블의 id, programmer_id 에만 index를 걸었는데, hos


![image](https://user-images.githubusercontent.com/47850258/138562998-e4799922-f546-43fe-9c5c-252db5b19f42.png)


### 4차 시도

쿼리도 서브쿼리를 JOIN 하도록 변경하고 또 (hospital_id, programmer_id)를 인덱스 컬럼으로 지정했습니다! 
Duration: `0.0046 s`
큰 차이는 아니지만 미세하게 줄었고, 또한 covid 테이블으 Full scan Table을 피한 것만으로 만족했습니다. 😂

![image](https://user-images.githubusercontent.com/47850258/138563519-e6ebea09-d130-4bfc-9a8e-82a1d22d3ce7.png)

![image](https://user-images.githubusercontent.com/47850258/138563507-cd7bef99-62c6-480f-8d12-3c72bb3a70e4.png)

![image](https://user-images.githubusercontent.com/47850258/138564012-14ce3a91-0ea0-4971-a4a6-0cf02b34fb17.png)


    - [ ] 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)

### 1차 시도 (순수 쿼리) 
![image](https://user-images.githubusercontent.com/47850258/138566043-7d4d4d6f-ae08-4104-aefa-cb8127dc41e7.png)

> Explain 
![image](https://user-images.githubusercontent.com/47850258/138566057-83b3ea2a-7db7-4cfe-bc2f-e72009ec538f.png)

```
Covid : 318325
Programmer: 98855
Hospital: 32
```

> Programmer 테이블을 개선해야할 것 같음! 

### 2차 시도 

Duration: 0.646s 

![image](https://user-images.githubusercontent.com/47850258/138566674-961b05e6-563b-4d9f-9979-6f4910de869e.png)

> Programmer index 설정

![image](https://user-images.githubusercontent.com/47850258/138566683-60e0bd34-280d-40a2-b1d5-43d7c5ca573c.png)

> Covid index 설정

![image](https://user-images.githubusercontent.com/47850258/138566692-bc4aba03-c492-4018-87ba-70fe7c66d820.png)

일단 이 결과로 만족하나... 몇몇 테스트를 더 진행해봅니다!! 

### 3차 시도 

> Programmer index 설정 변경 (index 순서 변경)
![image](https://user-images.githubusercontent.com/47850258/138566728-f33b36f8-fc46-4148-ab79-43e0eb27bab3.png)

줄긴 줄었다!  

Duraion: `0.533s`  

![image](https://user-images.githubusercontent.com/47850258/138566736-4ce3fbf3-d936-4b55-8f49-5601e5841120.png)


    - [x] 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)
### 1차 시도 
![image](https://user-images.githubusercontent.com/47850258/138567424-1f8c6c1e-fcc8-4212-bc63-4cd605f12a03.png)
(사진을 깜빡했는데... programmer table을 Full scan table 하고있음)


### 2차 시도 
> programmer 테이블의 country 컬럼 인덱스 추가함 

![image](https://user-images.githubusercontent.com/47850258/138567555-5358dc14-2cbf-498a-ac2e-79a4791b2d67.png)

![image](https://user-images.githubusercontent.com/47850258/138567569-6f869220-a76c-4c9a-87aa-b5e47de9d9fe.png)

Duration: `0.969s` 

일단 궤도권 진입!!! 

### 3차 시도 

> member table에 `age` 인덱스 컬럼 추가! 

Duration: `0.779s`

![image](https://user-images.githubusercontent.com/47850258/138567621-3995e165-ed97-41f2-9fff-720a494b8f36.png)


![image](https://user-images.githubusercontent.com/47850258/138567637-fd6c5e9a-6e06-463d-bcbe-9f477d82081c.png)


Explain 실행 결과 member table은 `Unique Key Lookup`으로 변경 됌! 
![image](https://user-images.githubusercontent.com/47850258/138567665-99c37286-79ee-4d34-8059-ec98e54c7415.png)


### 4차 시도 

기존에는 covid index를 (programmer_id, member_id, hospital_id)로 한번에 걸었으나, 이번에 각자 따로따로 걸어보았음.
효과가 매우 좋았다 👍

Duration: `0.140s` 

![image](https://user-images.githubusercontent.com/47850258/138567802-5c65b800-e1e6-4f65-aef1-e4e8fb3ccf99.png)


    - [ ] 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)
    
### 5차 시도 
(다른 변경점은 없음 SQL문 조건이 하나 빠졌다!  20대이기 때문에 `age < 30` 조건을 추가해야 함!) 
```MySQL
SELECT c.stay, COUNT(*)
FROM (SELECT * FROM subway.covid c) c
JOIN (SELECT * FROM subway.programmer p WHERE p.country = 'India') ip ON ip.id = c.programmer_id
JOIN (SELECT * FROM subway.hospital h WHERE h.name = '서울대병원') h ON h.id = c.hospital_id
JOIN (SELECT * FROM subway.member m WHERE m.age >= 20 AND m.age < 30) m ON m.id = c.member_id
GROUP BY c.stay
```

Duration: `0.091s` 

![image](https://user-images.githubusercontent.com/47850258/138568012-20e3d804-4b01-4e4e-a3fe-ebc66f15063c.png)

    
### 1차 시도 

> 작성한 쿼리문

```MySQL
SELECT p.exercise, COUNT(*)
FROM (SELECT * FROM subway.covid c) c
JOIN (SELECT * FROM subway.programmer p) p ON p.id = c.programmer_id 
JOIN (SELECT * FROM subway.hospital h WHERE h.name = "서울대병원") h 
JOIN (SELECT * FROM subway.member m WHERE m.age >= 30 AND m.age < 40) m ON m.id = c.member_id
GROUP BY p.exercise;
```

### 실행 결과 

![image](https://user-images.githubusercontent.com/47850258/138568189-f5c95097-999a-4d7b-868d-ba40a6a8b438.png)

Duration: `1.084s` (다시 실행해보니 더 낮게 나옴!, But 아직 요구사항 만족 X) 

### 2차 시도 
(지금보니 위의 쿼리는 잘못됌... hospital 조인문 보면 조건절인 ON 절이 없음) 

Driving Table을 가장 작은 테이블인 `hospital`로 변경 밑 빠진 조건절 채워넣고 실행 

```MySql
SELECT p.exercise, COUNT(*)
FROM (SELECT * FROM subway.hospital h WHERE h.name = "서울대병원") h 
JOIN (SELECT * FROM subway.covid c) c ON c.hospital_id = h.id
JOIN (SELECT * FROM subway.programmer p) p ON p.id = c.programmer_id 
JOIN (SELECT * FROM subway.member m WHERE m.age >= 30 AND m.age < 40) m ON m.id = c.member_id
GROUP BY p.exercise;
```

### 실행 결과 

![image](https://user-images.githubusercontent.com/47850258/138568459-95340121-5404-43ed-a414-0c3ec402ec74.png)

### Expain 실행결과

![image](https://user-images.githubusercontent.com/47850258/138568473-7cfd2d9b-9eca-4c48-9b56-cee9cd222895.png)

> 괜찮은 것 같기두....? 

> 여기서 의문인건... 같은 쿼리를 조건 변경없이 그대로 여러번 실행해보니까 Duration이 `0.044s` 까지도 나온다...뭐지...? 🤔

![image](https://user-images.githubusercontent.com/47850258/138568508-feff6f50-98c4-48a2-8c8b-e0e91a309fb4.png)


### 그 외 학습차원의 시도 


1번 
```MySQL
SELECT STRAIGHT_JOIN p.exercise, COUNT(*)
FROM (SELECT * FROM subway.hospital h WHERE h.name = "서울대병원") h 
JOIN (SELECT * FROM subway.covid c) c ON c.hospital_id = h.id
JOIN (SELECT * FROM subway.member m WHERE m.age >= 30 AND m.age < 40) m ON m.id = c.member_id
JOIN (SELECT * FROM subway.programmer p) p ON p.id = c.programmer_id 
GROUP BY p.exercise;
```

2번
```MySQL
SELECT STRAIGHT_JOIN p.exercise, COUNT(*)
FROM (SELECT * FROM subway.hospital h WHERE h.name = "서울대병원") h 
JOIN (SELECT * FROM subway.covid c) c ON c.hospital_id = h.id
JOIN (SELECT * FROM subway.programmer p) p ON p.id = c.programmer_id 
JOIN (SELECT * FROM subway.member m WHERE m.age >= 30 AND m.age < 40) m ON m.id = c.member_id
GROUP BY p.exercise;
```
위 두 쿼리는 Duration이 조금 차이가 난다. 
2번이 0.5s 정도 느림! 




<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>

