# 🚀 조회 성능 개선하기

## 생각해보기

![https://user-images.githubusercontent.com/48986787/136792017-52444d1d-6de2-42c8-8fd0-89b89f3bc22b.png](https://user-images.githubusercontent.com/48986787/136792017-52444d1d-6de2-42c8-8fd0-89b89f3bc22b.png)

## A. 쿼리 연습

### 실습환경 세팅

```
$ docker run -d -p 23306:3306 brainbackdoor/data-tuning:0.0.1
```

- [workbench](https://www.mysql.com/products/workbench/)를 설치한 후 localhost:23306 (ID : user, PW : password) 로 접속합니다.
1. 쿼리 작성만으로 1s 이하로 반환한다.
2. 인덱스 설정을 추가하여 50 ms 이하로 반환한다.
- [x]  활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)
- 급여 테이블의 사용여부 필드는 사용하지 않습니다. 현재 근무중인지 여부는 종료일자 필드로 판단해주세요.

![https://user-images.githubusercontent.com/48986787/136792075-39e09997-e57c-4f66-9b2f-7d7200474741.png](https://user-images.githubusercontent.com/48986787/136792075-39e09997-e57c-4f66-9b2f-7d7200474741.png)

### ERD 테이블 보기

테이블을 하나하나 살펴보기 힘드네요, Mysql에서 제공하는 ERD를 통해 확인해봐요. [ERD 자동생성](https://blog.naver.com/PostView.nhn?blogId=ajdkfl6445&logNo=221540488900&categoryNo=0&parentCategoryNo=0&viewDate=&currentPage=1&postListTopCurrentPage=1&from=postView)

![https://user-images.githubusercontent.com/48986787/136738094-3ded4729-5757-4d1f-8cb2-a0b0cef14af4.png](https://user-images.githubusercontent.com/48986787/136738094-3ded4729-5757-4d1f-8cb2-a0b0cef14af4.png)

생성된 DB의 ERD는 위와 같아요.

### 1. 쿼리 작성만으로 1s 이하로 반환한다.

**결과 쿼리**

```sql
SELECT `높은_연봉의_사원`.사원번호, `높은_연봉의_사원`.이름, `높은_연봉의_사원`.연봉, `높은_연봉의_사원`.직급명, 사원출입기록.입출입시간, 사원출입기록.지역, 사원출입기록.입출입구분
FROM (SELECT 사원.사원번호, 사원.이름, 급여.연봉, 직급.직급명
		FROM 사원
			JOIN 급여 ON 급여.사원번호 = 사원.사원번호
			JOIN 직급 ON 직급.사원번호 = 급여.사원번호
			JOIN 부서관리자 ON 부서관리자.사원번호 = 직급.사원번호
			JOIN 부서 ON 부서.부서번호 = 부서관리자.부서번호
		WHERE 급여.종료일자 = '9999-01-01' and 직급.종료일자 = '9999-01-01' 
			and 직급.직급명 = 'Manager' and 부서.비고 = 'active'
		ORDER BY 급여.연봉 desc 
		LIMIT 0,5) as `높은_연봉의_사원`
	JOIN 사원출입기록 ON 사원출입기록.사원번호 = `높은_연봉의_사원`.사원번호
WHERE 사원출입기록.입출입구분 = 'O' 
ORDER BY `높은_연봉의_사원`.연봉 desc, 사원출입기록.입출입시간 desc;
```

**결과 이미지** 

![https://user-images.githubusercontent.com/48986787/136782637-2e5764e9-3ab0-45bb-bdd6-99ab52ed0220.png](https://user-images.githubusercontent.com/48986787/136782637-2e5764e9-3ab0-45bb-bdd6-99ab52ed0220.png)

![https://user-images.githubusercontent.com/48986787/136782135-2260a571-a3bb-4631-903b-13474b924299.png](https://user-images.githubusercontent.com/48986787/136782135-2260a571-a3bb-4631-903b-13474b924299.png)

실행계획 (EXPLAIN)

![https://user-images.githubusercontent.com/48986787/136782251-aa684571-553b-4918-988a-8c92617ba414.png](https://user-images.githubusercontent.com/48986787/136782251-aa684571-553b-4918-988a-8c92617ba414.png)

**실행계획(WorkBench)**

![https://user-images.githubusercontent.com/48986787/136782549-d06ab5a4-92e1-4560-b8e3-fb89514c2eac.png](https://user-images.githubusercontent.com/48986787/136782549-d06ab5a4-92e1-4560-b8e3-fb89514c2eac.png)

### 2. 인덱스 설정을 추가하여 50 ms 이하로 반환한다.

**인덱스 추가 명령어**

```sql
CREATE INDEX `idx_사원_입출입구분_사원`  ON `tuning`.`사원출입기록` (사원번호,입출입구분);
```

하나의 인덱스를  추가했어요. 

**결과 이미지** 

![https://user-images.githubusercontent.com/48986787/136782637-2e5764e9-3ab0-45bb-bdd6-99ab52ed0220.png](https://user-images.githubusercontent.com/48986787/136782637-2e5764e9-3ab0-45bb-bdd6-99ab52ed0220.png)

![https://user-images.githubusercontent.com/48986787/136785462-6ae8183c-8beb-4b18-ba4f-962412f170c1.png](https://user-images.githubusercontent.com/48986787/136785462-6ae8183c-8beb-4b18-ba4f-962412f170c1.png)

실행계획 (EXPLAIN)

![https://user-images.githubusercontent.com/48986787/136788504-25004d7e-0a27-4995-8e9a-691ebbfc8e2f.png](https://user-images.githubusercontent.com/48986787/136788504-25004d7e-0a27-4995-8e9a-691ebbfc8e2f.png)

**실행계획(WorkBench)**

![https://user-images.githubusercontent.com/48986787/136788883-68d80d0a-74d2-4697-bb56-b88ffbc52493.png](https://user-images.githubusercontent.com/48986787/136788883-68d80d0a-74d2-4697-bb56-b88ffbc52493.png)


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

    - [ ] 각 프로그래머별로 해당하는 병원 이름을 반환하세요.  (covid.id, hospital.name)

    - [ ] 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)

    - [ ] 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)

    - [ ] 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)

<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>

## C. 프로젝트 요구사항

### a. 페이징 쿼리를 적용 

### b. Replication 적용 
