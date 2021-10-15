-- A

-- 1번 쿼리
SELECT 상위사원.사원번호, 상위사원.이름, 상위사원.직급명, 상위사원.연봉, 사원출입기록.지역, 사원출입기록.입출입구분 FROM
(SELECT 사원.사원번호, 사원.이름, 직급.직급명, 급여.연봉 FROM tuning.직급
join 사원 on 사원.사원번호 = 직급.사원번호
join 급여 on 급여.사원번호 = 사원.사원번호
where 직급.직급명='Manager' and 직급.종료일자='9999-01-01' and 급여.종료일자='9999-01-01'
order by 급여.연봉 desc
limit 5) as 상위사원
join 사원출입기록 on 사원출입기록.사원번호=상위사원.사원번호
where 입출입구분='O'
order by 상위사원.연봉 desc;

-- 2번 인덱스 추가를 통한 성능 향상
CREATE INDEX idx_직급명 on 직급 (직급명);
CREATE INDEX idx_사원번호 on 사원출입기록 (사원번호);


-- B
-- Coding As A Hobby

CREATE INDEX `idx_programmer_hobby`  ON `subway`.`programmer` (hobby) COMMENT '' ALGORITHM DEFAULT LOCK DEFAULT
-- 인덱스 생성

select
	(sum(case when stat.hobby = 'yes' then stat.count end) / sum(stat.count)) * 100 as 'yes(%)',
    (sum(case when stat.hobby = 'no' then stat.count end) / sum(stat.count)) * 100 as 'no(%)'
from 
	(SELECT hobby, COUNT(hobby) as count FROM subway.programmer group by hobby) as stat
-- 0.044 sec
