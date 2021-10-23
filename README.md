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

    - [ ] [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.


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

    - [ ] 각 프로그래머별로 해당하는 병원 이름을 반환하세요.  (covid.id, hospital.name)

    - [ ] 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)

    - [ ] 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)

    - [ ] 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)

<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>

## C. 프로젝트 요구사항

### a. 페이징 쿼리를 적용 

### b. Replication 적용 
