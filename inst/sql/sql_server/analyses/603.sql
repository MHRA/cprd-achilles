-- 603	Number of distinct procedure occurrence concepts per person

--HINT DISTRIBUTE_ON_KEY(count_value)
SELECT 
	COUNT_BIG(DISTINCT po.procedure_concept_id) AS count_value
INTO
	#tempRawData_603
FROM 
	@cdmDatabaseSchema.procedure_occurrence po
JOIN 
	@cdmDatabaseSchema.observation_period op 
ON 
	po.person_id = op.person_id
AND 
	po.procedure_date >= op.observation_period_start_date
AND 
	po.procedure_date <= op.observation_period_end_date
GROUP BY 
	po.person_id;

with overallStats (avg_value, stdev_value, min_value, max_value, total) as
(
  select CAST(avg(1.0 * count_value) AS FLOAT) as avg_value,
    CAST(stdev(count_value) AS FLOAT) as stdev_value,
    min(count_value) as min_value,
    max(count_value) as max_value,
    count_big(*) as total
  from #tempRawData_603
),
statsView (count_value, total, rn) as
(
  select count_value, 
  	count_big(*) as total, 
		row_number() over (order by count_value) as rn
  FROM #tempRawData_603
  group by count_value
),
priorStats (count_value, total, accumulated) as
(
  select s.count_value, s.total, sum(p.total) as accumulated
  from statsView s
  join statsView p on p.rn <= s.rn
  group by s.count_value, s.total, s.rn
)
select 603 as analysis_id,
  o.total as count_value,
  o.min_value,
	o.max_value,
	o.avg_value,
	o.stdev_value,
	MIN(case when p.accumulated >= .50 * o.total then count_value else o.max_value end) as median_value,
	MIN(case when p.accumulated >= .10 * o.total then count_value else o.max_value end) as p10_value,
	MIN(case when p.accumulated >= .25 * o.total then count_value else o.max_value end) as p25_value,
	MIN(case when p.accumulated >= .75 * o.total then count_value else o.max_value end) as p75_value,
	MIN(case when p.accumulated >= .90 * o.total then count_value else o.max_value end) as p90_value
into #tempResults_603
from priorStats p
CROSS JOIN overallStats o
GROUP BY o.total, o.min_value, o.max_value, o.avg_value, o.stdev_value
;

truncate table #tempRawData_603;
drop table #tempRawData_603;

--HINT DISTRIBUTE_ON_KEY(count_value)
select analysis_id, 
cast(null as varchar(255)) as stratum_1, cast(null as varchar(255)) as stratum_2, cast(null as varchar(255)) as stratum_3, cast(null as varchar(255)) as stratum_4, cast(null as varchar(255)) as stratum_5,
count_value, min_value, max_value, avg_value, stdev_value, median_value, p10_value, p25_value, p75_value, p90_value
into @scratchDatabaseSchema@schemaDelim@tempAchillesPrefix_dist_603
from #tempResults_603
;

truncate table #tempResults_603;
drop table #tempResults_603;
