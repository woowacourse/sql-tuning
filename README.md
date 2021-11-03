# 🚀 조회 성능 개선하기

## 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)

```sql
select 상위_연봉_부서관리자.사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간 from (
	select straight_join 사원.사원번호, 사원.이름, 급여.연봉, 직급.직급명 from 부서관리자
	left join 급여
		on 부서관리자.사원번호 = 급여.사원번호
	inner join 사원
		on 부서관리자.사원번호 = 사원.사원번호
	inner join 부서
		on 부서.부서번호 = 부서관리자.부서번호 and 부서.비고 = 'active'
	inner join 직급
		on 직급.사원번호 = 사원.사원번호
	where 부서관리자.종료일자 = "9999.01.01" 
		and 급여.종료일자 = "9999.01.01" 
        and 직급.종료일자 = "9999.01.01"
	order by 급여.연봉 desc
	limit 5
    ) as 상위_연봉_부서관리자
    inner join 사원출입기록
	on 상위_연봉_부서관리자.사원번호 = 사원출입기록.사원번호
    where 사원출입기록.입출입구분 = 'O'
```

단순 조인문제인것 같다. 모수를 최대한 줄이기 위해 상위 5명을 먼저 뽑아놓고 후에 사원출입기록과 join시켰다.

![image](https://user-images.githubusercontent.com/33603557/137583195-d5d4a541-d223-4298-9c5c-bafa6b97a0c2.png)

### 50ms 아래로 반환하기.

실패했습니다.

부서관리자, 급여, 직급의 종료일자에 인덱스를 걸고, 사원, 부서는 primary키를 이용, 사원 출입기록은 (사원번호, 입출입구분)으로 걸어줬는데 왜 60정도로 나오는지 ㅜㅜ 50 아래로는 안내려가네요... 이유가 뭘까요..?

![image](https://user-images.githubusercontent.com/33603557/137583205-44f249fd-c7bd-45b1-b84a-2cb76bdfb666.png)
![image](https://user-images.githubusercontent.com/33603557/137583207-9f5cee6c-d598-4287-af6b-e3639cee84cf.png)

무엇이 문제인지 모르겠습니다 으아아아아아아!!!!!

## [Coding as a Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.

![image](https://user-images.githubusercontent.com/33603557/137583216-c2fe337b-4cf6-4570-b2d7-5507af61dc50.png)


테이블을 보면 member_id가 null인것을 볼 수 있다.

![image](https://user-images.githubusercontent.com/33603557/137583219-ad6ae320-2c58-465b-9ce4-ba18dc22d4c2.png)
![image](https://user-images.githubusercontent.com/33603557/137583222-59d4c83f-ccc9-4136-9955-638b24d395ca.png)

또한 id필드의 최대값과 전체 컬럼의 count()를 보면 같은 값임을 알 수 있다.

결론적으로 이 테이블은 member를 soft delete한다. 따라서 id의 최대값이 전체 컬럼의 개수가 되며 이를 이용하면 쿼리 수행 속도를 최대한 감소시킬 수 있다. id를 pk로 만들면, innodb는 기본적으로 id를 정렬하여 저장한다. 즉, id의 최대값을 cost 1로 가져올 수 있는것이다.

또한 hobby의 no와 yes의 비율을 생각해 보자, no가 압도적으로 적은것을 알 수 있다. 이를 확용하면 아래와 같은 쿼리를 만들 수 있다.

```java
select
(100 - (round(count(hobby)/(select max(id) from programmer)*100, 1))) as yes,
round(count(hobby)/(select max(id) from programmer)*100, 1) as no
from programmer
where hobby = 'no';
```

![image](https://user-images.githubusercontent.com/33603557/137583227-7f5ad0b2-20a1-4be0-96f1-fcd9ff329c17.png)


## 프로그래머별로 해당하는 병원 이름을 반환하세요. ([covid.id](http://covid.id/), [hospital.name](http://hospital.name/))

문제가 잘못되어 있는 것 같아 ([programmer.i](http://programmer.id)d, [hospital.name](http://hospital.name))으로 수정한다.

기본적으로 프로그래머쪽에는 id가 PK로 걸려있다. 따라서 커버링 인덱스를 활용할 수 있을것이라고 판단된다.

![image](https://user-images.githubusercontent.com/33603557/137583236-31c7f2a2-8275-4e0e-919a-db9ccec6677d.png)

programmer index table

조인연산이 필요하다고 생각했고, 드라이브 테이블과 드리븐 테이블을 컨트롤 하기 위해서 각 테이블의 row를 확인했다.

**covid** : 318325

**programmer** : 98855

**hospital** : 32

```sql
explain select straight_join p.id, h.name from hospital h
inner join covid c
on h.id = c.hospital_id
inner join programmer p
on p.id = c.programmer_id
```

처음 시도한 쿼리이다.

![image](https://user-images.githubusercontent.com/33603557/137583240-05eaae5c-4541-47e1-9f38-2e439b5ba0cb.png)

![image](https://user-images.githubusercontent.com/33603557/137583243-2aec4ff8-7f62-42d8-aab6-378f34d6d125.png)


joinbuffer를 사용하고 Block Nested Loop를 이용한다. 그렇다는것은 join대상컬럼의 한쪽에 indexing이 안걸려있다는 것을 의미하고, 이는 성능저하로 이어지므로 인덱싱을 걸어주도록 한다.

![image](https://user-images.githubusercontent.com/33603557/137583249-465b6fd7-1657-45a4-ac3a-9225c0350431.png)

hospital의 경우는 id와 name컬럼만 존재한다. (id, name)으로 PK를 걸어주면 커버링 인덱스를 활용하여 병원 이름을 가져올 수 있을것이다.

![image](https://user-images.githubusercontent.com/33603557/137583251-f2c11966-43d5-4aeb-ac9b-8cc4cca20c68.png)

name의 type을 varchar로 변경하고 id와 name에 pk를 걸어줬다.

![image](https://user-images.githubusercontent.com/33603557/137583260-10ec8e3b-4b77-4966-9deb-6ae02eb9d6e3.png)

covid측에도 hospital_id와 programmer_id에 index를 걸어줬다.

![image](https://user-images.githubusercontent.com/33603557/137583268-0a84beb2-3fad-4ff5-aa60-5b3360929b0f.png)

![image](https://user-images.githubusercontent.com/33603557/137583276-4e0e3c8c-d9fa-4406-a381-85ef8729dbe5.png)


성능이 기존보다 40%가량 향상되었다.

그런데 생각해보니 programmer_id의 경우는 굳이 join이 필요 없다. covid테이블에 있는 데이터를 그대로 가져오면 된다. 따라서 해당 join을 제거한다.

```sql
select straight_join c.programmer_id, h.name from hospital h
inner join covid c
on h.id = c.hospital_id
```

![image](https://user-images.githubusercontent.com/33603557/137583290-c495c1f4-b220-407d-a1e7-158e2c62df00.png)

ㄹ![image](https://user-images.githubusercontent.com/33603557/137583401-0c25ba1a-75ec-44bc-b764-29ff74a940e6.png)


using index condition은 왜 뜨는거지?

## **프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 [user.id](http://user.id/) 기준으로 정렬하세요. ([covid.id](http://covid.id/), [hospital.name](http://hospital.name/), user.Hobby, user.DevType, user.YearsCoding)**

```sql
select c.id, h.name, p.hobby, p.dev_type, p.years_coding from programmer p
inner join covid c
on c.programmer_id = p.id
inner join hospital h 
on c.hospital_id = h.id
where (p.hobby = 'yes' and p.years_coding like "0-2%") or p.dev_type like "%student%"
order by p.id
```

기본적인 쿼리이다.

이제 인덱싱을 적절하게 걸어서 성능 최적화를 진행해 보도록 한다.

### 이 문제는 인덱싱을 통한 쿼리 최적화에 한계가 있다.

기본적으로 이 문제는 join을 위한 인덱싱 이외에는 쿼리 최적화에 한계가 있다고 생각합니다.

쿼리 최적화를 수행해야하는 부분은 where절에 걸리는 programmer와 관련된 컬럼들과 관련이 있다. where절을 확인하면 hobby, years_coding, dev_type에 대한 조건을 걸어주는것을 확인할 수 있다.

일단, id를 기준으로 정렬하는것은 id를 pk로 잡음으로서 클러스터링 인덱스를 활용하여 order 비용을 제거할 수 있다.

hobby와 years_coding 도 마찬가지이다. 만일 dev_type 조건이 없다면은 복합인덱스와 커버링 인덱스틑 통해서 최적화가 가능했을 것이다. 하지만 문제는 dev_type에 있다. devt_type은 text형식이기 때문에 인덱싱이 불가능하며 인덱싱이 가능하더라도 들어가 있는 데이터의 형식이 제각각이므로 `"%student%"` 를 이용할수밖에 없다.

스토리지 엔진은 기본적으로 where 조건절에서 index를 사용할 수 있는 데이터를 테이블에서 추출한다. 그리고 mysql 엔진은 추출된 데이터에서 인덱스가 아닌 컬럼에 대하여 추출한다.

하지만 현재 필요한 쿼리를 보면 or가 들어가 있다. 이것은 즉, hobby, years_coding에 대해서 인덱스를 걸었더라도 or dev_type으로 인해 결국 인덱스를 활용하지 못하게 된다는 것을 의미한다.

![image](https://user-images.githubusercontent.com/33603557/137583298-7e0fdd5e-3749-40fd-9dc9-cbd7183205a8.png)


현재 hobby와 years_coding으로 복합인덱스를 걸어놓으 상태이다. 그럼에도 인덱스 풀 스캔을 사용하는것을 알 수 있다.

그렇다면 or을 and로 바꿔보자.

![image](https://user-images.githubusercontent.com/33603557/137583300-f07400c0-2f0a-4d4e-b815-61243f0474df.png)

type이 range, 즉 레인지 스캔을 이용함과 동시에 (hobby, years_coding) 인덱스를 사용할 수 있음으로 인덱스 푸시 다운과 using where을 이용하는것을 볼 수 있다. and의 경우는 인덱스를 이용하여 hobby, years_coding과 관려된 row를 뽑아낼 수 있기 때문에 이러한 결과가 나오는 것이다.

따라서 이 경우는 따로 인덱스를 걸지 않더라도(pk와 join 제외) 성능을 만족시킬 수 있다.

![image](https://user-images.githubusercontent.com/33603557/137583301-473ac12d-2960-4d42-926a-020d61ec55ea.png)


## **서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)**

```sql
select c.stay, count(*) from member m
inner join covid c
on c.member_id = m.id
where c.hospital_id = (select id from hospital where name="서울대병원")
and m.age between 20 and 29
group by c.stay
order by null;
```

시작 쿼리는 위와 같다.

age를 범위로 가지고 오기 때문에 age에 인덱스를 걸었으면 hospital의 id는 pk, name에는 인덱스를 걸어 커버링 인덱스를 활용할 수 있도록 하였다.

그 이외에 join을 위한 인덱스르 걸었다. mysql의 경우 group by를 사용하면 기본적으로 ordering이 진행되고 따라서 file sort가 발생한다. 따라서 이를 방지하기 위해 mysql만의 문법인 group by 뒤의 order by null을 통해 ordering을 하지 않겠다는 명시를 진행하였다.

![image](https://user-images.githubusercontent.com/33603557/137583304-fead4f09-edef-4926-9ab6-981645db0146.png)

![image](https://user-images.githubusercontent.com/33603557/137583305-bfa92222-3985-44bd-91e6-bdcf943de0f3.png)

![image](https://user-images.githubusercontent.com/33603557/137583309-5874d9a9-f55c-4e38-8e75-77b85a7c3193.png)


group by를 사용하기고, sum이나 min같은 집계함수를 사용하지 않기때문에 인덱스 루스스캔을 사용하기는 어려워 보인다. 따라서 어쩔 수 없이 Using temporary를 허용했다. 여기서 신기한 점은 country에 인덱스를 걸면 오히려 느려진다는점이다. 이유가 무엇일까..

![image](https://user-images.githubusercontent.com/33603557/137583425-8d53ff65-108d-4271-965e-1264899a3c6f.png)

![image](https://user-images.githubusercontent.com/33603557/137583440-48cb4d0c-08cd-4c4c-9cbc-230e83a30914.png)

![image](https://user-images.githubusercontent.com/33603557/137583443-44482626-c52b-4313-b5e9-3dbb8239d3cc.png)



인덱스를 걸면 쿼리코스트는 줄어든다. 하지만 시간은 약 2배가 더 나온다.. 왜지..? 필터 비용이 더 크기때문이라고 걍 혼자 생각하기로 했다... 하...

ordering을 하지 않겠다고 명시하였기 때문에 order에서 cost는 들지 않는다.

또 이해가 안가는 부분이 있다. 위 쿼리에 straight_join을 걸었을떄의 문제이다

![image](https://user-images.githubusercontent.com/33603557/137583467-46d82e42-fffb-40d2-8784-04b424c7ada9.png)



member테이블의 row가 4만으로 올랐다. where 절의과 on 절의 영향때문인가 여러 실험을 돌려봤지만, 4만의 row를 얻는 경우는 없었다. 위 순서대로 join을 진행하면 왜 rows가 더 높게나오고, covid 테이블의 row 또한 3으로 증가하는것일까..? 아무리 찾아도 모르겠다...

## 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)

```sql
explain select exercise, count(*) 
from covid c
inner join member m
on c.member_id = m.id
inner join programmer p 
on c.programmer_id = p.id
inner join hospital h
on c.hospital_id = h.id and h.name = "서울대병원"
where m.age between 30 and 39
group by p.exercise
order by null
```

이전 문제와 비슷한것 같다. join과 연관된 컬럼은 다 인덱스를 걸었다.

![image](https://user-images.githubusercontent.com/33603557/137583331-b44b1b18-f096-4cec-8a82-93b4c98cce8b.png)


마찬가지로 group by를 사용하기 때문에 tmp 테이블의 생성은 피할 수 없었다(루스스캔 사용 불가능).

![image](https://user-images.githubusercontent.com/33603557/137583336-a92a8fb1-8d17-4f2c-90f8-2d16af3bcb33.png)
