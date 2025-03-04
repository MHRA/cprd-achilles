-- 703	Number of distinct drug exposure concepts per person

DROP TABLE IF EXISTS #tempResults_703;
DROP TABLE IF EXISTS #temp_rawdata_703;

--HINT DISTRIBUTE_ON_KEY(count_value)
SELECT 
    COUNT_BIG(DISTINCT de.drug_concept_id) AS count_value
INTO 
    #temp_rawdata_703
FROM 
	@cdmDatabaseSchema.drug_exposure de
JOIN 
	@cdmDatabaseSchema.observation_period op 
ON 
	de.person_id = op.person_id
AND 
	de.drug_exposure_start_date >= op.observation_period_start_date
AND 
	de.drug_exposure_start_date <= op.observation_period_end_date
GROUP BY 
	de.person_id;
	
WITH overallStats (avg_value, stdev_value, min_value, max_value, total) as
(
  select CAST(avg(1.0 * count_value) AS FLOAT) as avg_value,
    CAST(stdev(count_value) AS FLOAT) as stdev_value,
    min(count_value) as min_value,
    max(count_value) as max_value,
    count_big(*) as total
  from #temp_rawData_703
),
statsView (count_value, total, rn) as
(
  select count_value, 
  	count_big(*) as total, 
		row_number() over (order by count_value) as rn
  FROM #temp_rawData_703
  group by count_value
),
priorStats (count_value, total, accumulated) as
(
  select s.count_value, s.total, sum(p.total) as accumulated
  from statsView s
  join statsView p on p.rn <= s.rn
  group by s.count_value, s.total, s.rn
)
select 703 as analysis_id,
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
into #tempResults_703
from priorStats p
CROSS JOIN overallStats o
GROUP BY o.total, o.min_value, o.max_value, o.avg_value, o.stdev_value
;

--HINT DISTRIBUTE_ON_KEY(count_value)
select analysis_id, 
cast(null as varchar(255)) as stratum_1, cast(null as varchar(255)) as stratum_2, cast(null as varchar(255)) as stratum_3, cast(null as varchar(255)) as stratum_4, cast(null as varchar(255)) as stratum_5,
count_value, min_value, max_value, avg_value, stdev_value, median_value, p10_value, p25_value, p75_value, p90_value
into @scratchDatabaseSchema@schemaDelim@tempAchillesPrefix_dist_703
from #tempResults_703
;

truncate table #tempResults_703;
drop table #tempResults_703;

truncate table #temp_rawdata_703;
drop table #temp_rawdata_703;
