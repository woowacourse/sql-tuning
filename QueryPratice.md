# A. 쿼리 연습

1단계 active한 부서의 현직 부서장들의 정보 구하기 부서

 d(deparment)부서관리자 

dm(deparment manager)

select * from 부서 d, 부서관리자 dm 

where d.비고 = "active" and d.부서번호 = dm.부서번호 and dm.종료일자 = "9999-01-01";



2단계 사원 정보로 치환하기

사원 edms 

부서장들 dms

select * from 사원 e, 

(select dm.사원번호 from 부서 d, 부서관리자 dm where d.비고 = "active" and d.부서번호 = dm.부서번호 and dm.종료일자 = "9999-01-01") dms 

where e.사원번호 = dms.사원번호;



3단계 직급명 포함시키기

select eh.사원번호, eh.이름, p.직급명 from 

(select e.사원번호, e.이름 from 사원 e, 

(select dm.사원번호 from 부서 d, 부서관리자 dm where d.비고 = "active" and d.부서번호 = dm.부서번호 and dm.종료일자 = "9999-01-01") dms 

where e.사원번호 = dms.사원번호) eh,직급 p where eh.사원번호 = p.사원번호 and p.종료일자 = "9999-01-01";



4단계해당 사원들 최고 연봉 조회

select s.사원번호, max(s.연봉) 연봉, b.이름, b.직급명 from 급여 s, 

(select eh.사원번호, eh.이름, p.직급명 from 

(select e.사원번호, e.이름 from 사원 e, 

(select dm.사원번호 from 부서 d, 부서관리자 dm where d.비고 = "active" and d.부서번호 = dm.부서번호 and dm.종료일자 = "9999-01-01") dms 

where e.사원번호 = dms.사원번호) eh,

직급 p where eh.사원번호 = p.사원번호 and p.종료일자 = "9999-01-01") b 

where s.사원번호 = b.사원번호 group by b.사원번호, b.직급명 order by 연봉 desc limit 0,5;



5단계각 사원들의 제일 늦은 퇴근 시간

select c.사원번호, c.입출입구분, c.지역, g.입출입시간 from 사원출입기록 c,

(select 사원번호, 입출입구분, max(입출입시간) 입출입시간 from 사원출입기록 

where 입출입구분 = "O" group by 사원번호) g

where c.사원번호 = g.사원번호 and c.입출입시간 = g.입출입시간;



6단계 퇴실시간 추가

select a.사원번호, a.이름, a.연봉, a.직급명, t.지역, t.입출입구분, t.입출입시간 from 

(select s.사원번호, max(s.연봉) 연봉, b.이름, b.직급명 from 급여 s,

 (select eh.사원번호, eh.이름, p.직급명 from 

(select e.사원번호, e.이름 from 사원 e, 

(select dm.사원번호 from 부서 d, 부서관리자 dm where d.비고 = "active" and d.부서번호 = dm.부서번호 and dm.종료일자 = "9999-01-01") dms 

where e.사원번호 = dms.사원번호) eh,직급 p

 where eh.사원번호 = p.사원번호 and p.종료일자 = "9999-01-01") b 

where s.사원번호 = b.사원번호 group by b.사원번호, b.직급명 order by 연봉 desc limit 0,5) a, 

(select c.사원번호, c.입출입구분, c.지역, g.입출입시간 from 사원출입기록 c, 

(select 사원번호, 입출입구분, max(입출입시간) 입출입시간 from 사원출입기록 where 입출입구분 = "O" group by 사원번호) g 

where c.사원번호 = g.사원번호 and c.입출입시간 = g.입출입시간) t 

where a.사원번호 = t.사원번호;



실행결과

![result](./QueryPractice.png)

