# 🚀 조회 성능 개선하기

## A. 쿼리 연습

### 실습환경 세팅

```sh
$ docker run -d -p 23306:3306 brainbackdoor/data-tuning:0.0.1
```

- [workbench](https://www.mysql.com/products/workbench/)에서 localhost:23306 (ID: user, PW: password)로 접속한다.

### 요구사항

> 활동 중인(Active) 부서의 현재 부서 관리자 중 연봉 상위 5위 안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회한다.
> - 사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간
> - 급여 테이블의 사용여부 필드는 사용하지 X
> - 현재 근무 중인지 여부는 종료일자 필드로 판단한다.

<br/>

- [x] 쿼리 작성만으로 1s 이하로 반환한다.

<details>
  <summary>쿼리 작성</summary>
  <br/>

  ```sql
  select 
      사원.사원번호, 
      사원.이름, 
      급여.연봉,
      직급.직급명
  from 
      사원
  join 
      급여 on 사원.사원번호 = 급여.사원번호
  join 
      부서관리자 on 사원.사원번호 = 부서관리자.사원번호
  join
      직급 on 사원.사원번호 = 직급.사원번호
  join 
      부서 on 부서관리자.부서번호 = 부서.부서번호
  where 
      급여.종료일자 = '9999-01-01' and 
      부서관리자.종료일자 = '9999-01-01' and 
      직급.직급명 = 'Manager' and
      부서.비고 = 'active'
  order by 
      급여.연봉 desc
  limit 5;
  
  select 
      사원_top5.사원번호, 
      사원_top5.이름, 
      사원_top5.연봉, 
      사원_top5.직급명, 
      사원출입기록.입출입시간, 
      사원출입기록.지역, 
      사원출입기록.입출입구분
  from 
      사원출입기록
  join (
      select 
          사원.사원번호, 
          사원.이름, 
          급여.연봉,
          직급.직급명
      from 
          사원
      join 
          급여 on 사원.사원번호 = 급여.사원번호
      join 
          부서관리자 on 사원.사원번호 = 부서관리자.사원번호
      join
          직급 on 사원.사원번호 = 직급.사원번호
      join 
          부서 on 부서관리자.부서번호 = 부서.부서번호
      where 
          급여.종료일자 = '9999-01-01' and 
          부서관리자.종료일자 = '9999-01-01' and 
          직급.직급명 = 'Manager' and
          부서.비고 = 'active'
      order by 
          급여.연봉 desc
      limit 5
  ) as 사원_top5 on 사원출입기록.사원번호 = 사원_top5.사원번호
  where 
      사원출입기록.입출입구분 = 'O'
  order by 
      사원_top5.연봉 desc,
      사원출입기록.입출입시간 desc;
  ```

</details>

<details>
  <summary>실행 결과</summary>
  
  #### 소요 시간
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137327316-03bd818c-65cb-478a-abf5-7da0ca112cf9.png">
  </p>

  #### 테이블 출력
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137328626-5a7d8bfa-2b97-4979-a636-ab3d0741561f.png">
  </p>

  #### 실행 계획
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137470893-7f02025f-97b2-462e-b504-97697e61e3e5.png">
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137478973-b4ca7918-8072-4f84-a5f6-122b309c9efe.png">
  </p>

</details>

<details>
  <summary>질문</summary>

  #### 1.
  문제에서 "~ `최근에` 각 지역별로 언제 퇴실했는지 조회한다."라고 돼있는데요.<br/>
  이 뜻은 입출입시간을 기준으로 내림차순 정렬하라는 걸까요?<br/>
  현재는 이렇게 작성되어 있는데, 검프의 생각이 궁금합니다!<br/>

  #### 2.
  강의 자료의 정답과 비교하면, 테이블의 입출입시간이 맞지 않는데요.<br/>
  혹시 쿼리가 틀린 건가 고민하다 정답의 값이 있긴 한 건지 먼저 확인해야겠다 싶어 `사원번호 110039`를 기준으로 조회해봤습니다.<br/>
  
  ```sql
  select *
  from 사원출입기록
  where 사원번호 = 110039;
  ```
  <br/>
  
  테이블은 아래처럼 출력됐어요.<br/>
  정답에 있는 입출입시간 값(e.g. 2020-09-06)이 아예 없었습니다.<br/>
  저만 그런가 싶어 몇몇 크루들한테 물어봤는데, 저와 같은 경우도 있고 아닌 경우도 있더라구요 😵‍💫<br/>
  검프는 결과가 똑같이 나오나요??<br/>

  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137324185-7e567174-9ac5-474c-81b4-cc30af339fda.png">
  </p>

</details>

<br/>
    
- [x] 인덱스 설정을 추가하여 50ms 이하로 반환한다.

<details>
  <summary>쿼리 작성</summary>
  <br/>

  ```sql
  create index `idx_사원번호` on 사원출입기록 (사원번호);
  ```

</details>

<details>
  <summary>실행 결과</summary>

  #### 소요 시간
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137478470-80ab4752-3c1a-453a-9857-f8675409350c.png">
  </p>

  #### 실행 계획
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137478764-52e8b000-e8c3-490a-ad5f-07448b087bb4.png">
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137478881-ddc20dec-d35d-42ef-b2b3-cbd71ca6abba.png">
  </p>

</details>

<details>
  <summary>질문</summary>
  <br/>

  기존에는 `사원출입기록`에 아래처럼 인덱스가 걸려 있어, 조인을 할 때 Full Table Scan이 발생했습니다.<br/>

  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137479229-248f8549-9c51-475a-9c30-b31a74857efa.png">  
  </p>
  <br/>

  그래서 Full Table Scan을 해결하려 (사원번호)로 인덱스를 걸었는데요.<br/>
  그리고 실행 시간을 확인하니 67-70ms 정도는 나오는데, 50ms 이하로는 안 나오더라구요 🥲<br/>
  다른 곳도 개선할 수 있는 부분이 있을까 싶어 여기저기 찾아보고 인덱스를 걸어봤는데요.<br/>
  오히려 실행 시간이 늘어나는 경우도 있고, 딱히 나아지지 않았습니다 😂<br/>
  검프는 어디에 인덱스를 추가해줬나요? 혹시 제가 놓친 게 있을까요??<br/>

</details>

<br/>

## B. 인덱스 설계

### 실습환경 세팅

```sh
$ docker run -d -p 13306:3306 brainbackdoor/data-subway:0.0.2
```

- [workbench](https://www.mysql.com/products/workbench/)에서 localhost:13306 (ID: root, PW: masterpw)로 접속한다.


### 요구사항

> 주어진 데이터셋을 활용하여 조회 결과를 100ms 이하로 반환한다.

- [ ] [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.
- [ ] 각 프로그래머별로 해당하는 병원 이름을 반환하세요.  (covid.id, hospital.name)
- [ ] 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)
- [ ] 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)
- [ ] 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)

<br/>

## C. 프로젝트 요구사항

### a. 페이징 쿼리를 적용 

### b. Replication 적용 
