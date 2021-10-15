-- A

-- 1번 쿼리
SELECT 상위사원.사원번호, 상위사원.이름, 상위사원.직급명, 상위사원.연봉, 사원출입기록.지역, 사원출입기록.입출입구분 FROM
(SELECT 사원.사원번호, 사원.이름, 직급.직급명, 급여.연봉 FROM tuning.직급
JOIN 사원 ON 사원.사원번호 = 직급.사원번호
JOIN 급여 ON 급여.사원번호 = 사원.사원번호
WHERE 직급.직급명='Manager' AND 직급.종료일자='9999-01-01' AND 급여.종료일자='9999-01-01'
ORDER BY 급여.연봉 DESC
LIMIT 5) AS 상위사원
JOIN 사원출입기록 ON 사원출입기록.사원번호=상위사원.사원번호
WHERE 입출입구분='O'
ORDER BY 상위사원.연봉 DESC;

-- 2번 인덱스 추가를 통한 성능 향상
CREATE INDEX idx_직급명 ON 직급 (직급명);
CREATE INDEX idx_사원번호 ON 사원출입기록 (사원번호);


-- B
-- Coding As A Hobby

CREATE INDEX `idx_programmer_hobby` ON `subway`.`programmer` (hobby) COMMENT '' ALGORITHM DEFAULT LOCK DEFAULT
-- 인덱스 생성

SELECT
	(sum(CASE WHEN stat.hobby = 'yes' THEN stat.count END) / sum(stat.count)) * 100 AS 'yes(%)',
    (sum(CASE WHEN stat.hobby = 'no' THEN stat.count END) / sum(stat.count)) * 100 AS 'no(%)'
FROM
	(SELECT hobby, COUNT(hobby) AS count FROM subway.programmer GROUP BY hobby) AS stat
-- 0.044 sec

-- 프로그래머별로 해당하는 병원 이름을 반환
-- 인덱스 생성
CREATE UNIQUE INDEX `idx_covid_id`  ON `subway`.`covid` (id) COMMENT '' ALGORITHM DEFAULT LOCK DEFAULT;
CREATE UNIQUE INDEX `idx_programmer_id` ON programmer (id) COMMENT '' ALGORITHM DEFAULT LOCK DEFAULT;
ALTER TABLE covid ADD FOREIGN KEY(member_id) REFERENCES member(id);
ALTER TABLE covid ADD FOREIGN KEY(programmer_id) REFERENCES programmer(id);
ALTER TABLE covid MODIFY id bigint(20);
ALTER TABLE covid ADD FOREIGN KEY(hospital_id) REFERENCES hospital(id);

SELECT covid.id, hospital.name FROM covid
JOIN programmer ON covid.programmer_id = programmer.id
JOIN hospital ON covid.hospital_id = hospital.id;
-- 0.0056 sec
