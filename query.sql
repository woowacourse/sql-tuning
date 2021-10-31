-- A

-- 1번 쿼리
SELECT 상위사원.사원번호, 상위사원.이름, 상위사원.직급명, 상위사원.연봉, 사원출입기록.지역, 사원출입기록.입출입구분
  FROM
    (SELECT 사원.사원번호, 사원.이름, 직급.직급명, 급여.연봉
		  FROM tuning.직급
        JOIN 사원 ON 사원.사원번호 = 직급.사원번호
        JOIN 급여 ON 급여.사원번호 = 사원.사원번호
        JOIN 부서사원_매핑 ON 부서사원_매핑.사원번호 = 사원.사원번호
        JOIN 부서 ON 부서.부서번호 = 부서사원_매핑.부서번호
      WHERE 직급.직급명='Manager' AND 직급.종료일자='9999-01-01' AND 급여.종료일자='9999-01-01' AND 부서.비고 ='active'
      ORDER BY 급여.연봉 DESC LIMIT 5) AS 상위사원
    JOIN 사원출입기록 ON 사원출입기록.사원번호=상위사원.사원번호
    WHERE 입출입구분='O'
ORDER BY 상위사원.연봉 DESC;

-- 2번 인덱스 추가를 통한 성능 향상
CREATE INDEX idx_직급명 ON 직급 (직급명);
CREATE INDEX idx_사원번호 ON 사원출입기록 (사원번호);


-- B
-- 1. Coding As A Hobby

CREATE INDEX `idx_programmer_hobby` ON `subway`.`programmer` (hobby) COMMENT '' ALGORITHM DEFAULT LOCK DEFAULT
-- 인덱스 생성

SELECT
  (sum(CASE WHEN stat.hobby = 'yes' THEN stat.count END) / sum(stat.count)) * 100 AS 'yes(%)',
  (sum(CASE WHEN stat.hobby = 'no' THEN stat.count END) / sum(stat.count)) * 100 AS 'no(%)'
FROM
	(SELECT hobby, COUNT(hobby) AS count FROM subway.programmer GROUP BY hobby) AS stat
-- 0.044 sec


-- 2. 프로그래머별로 해당하는 병원 이름을 반환

CREATE UNIQUE INDEX `idx_covid_id`  ON `subway`.`covid` (id) COMMENT '' ALGORITHM DEFAULT LOCK DEFAULT;
CREATE UNIQUE INDEX `idx_programmer_id` ON `subway`.`programmer` (id) COMMENT '' ALGORITHM DEFAULT LOCK DEFAULT;
ALTER TABLE covid ADD FOREIGN KEY(member_id) REFERENCES member(id);
ALTER TABLE covid ADD FOREIGN KEY(programmer_id) REFERENCES programmer(id);
ALTER TABLE covid MODIFY id bigint(20);
ALTER TABLE covid ADD FOREIGN KEY(hospital_id) REFERENCES hospital(id);
-- 인덱스 생성

SELECT covid.id, hospital.name
  FROM covid
    JOIN hospital ON covid.hospital_id = hospital.id
WHERE covid.programmer_id IS NOT NULL;
-- 0.0025 sec


-- 3. 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬

CREATE INDEX `idx_programmer_hobby_student`  ON `subway`.`programmer` (hobby, student) COMMENT '' ALGORITHM DEFAULT LOCK DEFAULT
CREATE INDEX `idx_programmer_student_years_coding_prof`  ON `subway`.`programmer` (student, years_coding_prof) COMMENT '' ALGORITHM DEFAULT LOCK DEFAULT
-- 인덱스 생성

SELECT programmer.id, hospital.name, programmer.hobby, programmer.dev_type, programmer.years_coding 
  FROM programmer
    JOIN covid ON covid.programmer_id = programmer.id
    JOIN hospital ON hospital.id = covid.hospital_id
    WHERE programmer.hobby = 'yes'
      AND (programmer.years_coding_prof = '0-2 years' OR programmer.student >= 'Yes, full-time');
-- 0.025 sec


-- 4. 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계

CREATE INDEX `idx_member_age`  ON `subway`.`member` (age) COMMENT '' ALGORITHM DEFAULT LOCK DEFAULT
-- 인덱스 생성

SELECT covid.stay, COUNT(covid.stay)
  FROM hospital
    JOIN covid ON covid.hospital_id = hospital.id
      JOIN member ON member.id = covid.member_id
      JOIN programmer ON programmer.id = covid.programmer_id
  WHERE hospital.name = '서울대병원' AND (member.age > 19 AND member.age < 30) AND programmer.country = 'India'
GROUP BY covid.stay;
-- 0.043 sec


-- 5. 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계

ALTER TABLE programmer MODIFY exercise varchar(32);
-- 칼럼 타입 변경
CREATE INDEX `idx_programmer_exercise`  ON `subway`.`programmer` (exercise) COMMENT '' ALGORITHM DEFAULT LOCK DEFAULT
-- 인덱스 생성

SELECT programmer.exercise, COUNT(programmer.exercise)
  FROM hospital
    JOIN covid ON covid.hospital_id = hospital.id
      JOIN member ON member.id = covid.member_id
      JOIN programmer ON programmer.id = covid.programmer_id
  WHERE hospital.name = '서울대병원' AND (member.age > 29 AND member.age < 40)
GROUP BY programmer.exercise;
-- 0.082 sec
