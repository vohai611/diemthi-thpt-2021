README
================
Haivo
7/30/2021

# Intro

This repository provide a simple R script to get Vietnam highschool
graduate exam in 2020. Data are saved in data folder. This README files
show how the process are done.

There are several website provide web interface to get the score. In
this script, I use <https://diemthi.vnanet.vn> and
<https://tienphong.vn/tra-cuu-diem-thi.tpo>. Under the hood, these two
website use API to retrieve the data, and user can access this API
directly via safari web browser devtools (network tab). The API from
vnanet.vn is quite slow and only allow to retrieve 1 result per request.
tienphong.vn on the other hand, allow user to get a maximum of 300
result per request, hence I decide to use the latter options to get the
whole data. These two API take the student ID as input and provide full
result of that student as output. Input are in the form
{province\_code}{student\_id}. Province\_code vary from 01 to 64, while
the student\_id are from 1 to the max number of student attend in the
exam. For example, input = ‘01000001’ is for student 1 from the province
that had code 01 (Ha Noi).

# Demonstration:

Option 1:  

``` r
library(tidyverse)
library(glue)
library(httr)

get_score <- function(sbd) {
  url <- glue("https://diemthi.vnanet.vn/Home/SearchBySobaodanh?code={ sbd }&nam=2021")
  GET(url) %>% 
    content(type = 'text',encoding = 'UTF-8') %>% 
    jsonlite::fromJSON() %>% 
    .[['result']] %>% 
    as_tibble()
}

get_score('01000001') %>% 
  knitr::kable()
```

| CityCode | CityArea | Code     | Toan | NguVan | NgoaiNgu | VatLi | HoaHoc | SinhHoc | KHTN | DiaLi | LichSu | GDCD | KHXH | ResultGroup                                                                                | Result |
|:---------|:---------|:---------|:-----|:-------|:---------|:------|:-------|:--------|:-----|:------|:-------|:-----|:-----|:-------------------------------------------------------------------------------------------|:-------|
| 01       | NA       | 01000001 | 2.20 | 3.50   |          |       |        |         |      | 5.50  | 2.50   |      |      | \[{“g”:“A07”,“p”:10.20},{“g”:“C00”,“p”:11.50},{“g”:“C03”,“p”:8.20},{“g”:“C04”,“p”:11.20}\] |        |

Option 2:  
In this API options, I can use sbd = ‘0100001’ to get the result of 10
attendance in one request from 01000011 to 01000019

``` r
get_score2 <- function(sbd){
  
  # prepare URL
  url <- glue('https://tienphong.vn/api/diemthi/get/result?type=0&keyword={ sbd }&kythi=THPT&nam=2021&cumthi=0')
  ## send request
  a <- GET(url,
           add_headers('referer'= 'https://tienphong.vn/tra-cuu-diem-thi.tpo')
  ) %>% 
    content(as = 'text') %>% 
    jsonlite::fromJSON()
  
  # parse request to text format
  a$data$results %>% 
    rvest::read_html() %>% 
    rvest::html_text2() %>% 
    return()
}

# data received in the form of TSV:
get_score2('0100001') %>% 
  data.table::fread() %>% 
  knitr::kable()
```

|  V1 |      V2 |  V3 |   V4 |  V5 |   V6 |   V7 |   V8 |   V9 |  V10 |  V11 | V12 |
|----:|--------:|----:|-----:|----:|-----:|-----:|-----:|-----:|-----:|-----:|:----|
|   1 | 1000019 | 7.0 | 8.50 | 8.8 |   NA |   NA |   NA | 4.00 | 5.25 | 6.75 | NA  |
|   2 | 1000018 | 8.8 | 8.25 |  NA | 8.00 | 5.00 | 6.75 |   NA |   NA |   NA | NA  |
|   3 | 1000017 | 7.8 | 8.00 | 9.6 | 7.50 | 8.00 | 7.25 |   NA |   NA |   NA | NA  |
|   4 | 1000016 | 7.8 | 8.50 | 9.4 |   NA |   NA |   NA | 6.50 | 7.50 | 8.00 | NA  |
|   5 | 1000015 | 6.0 | 7.75 | 9.0 |   NA |   NA |   NA | 4.00 | 7.75 | 7.00 | NA  |
|   6 | 1000014 | 7.4 | 8.00 | 8.6 |   NA |   NA |   NA | 6.00 | 6.25 | 7.50 | NA  |
|   7 | 1000013 | 7.4 | 6.75 | 9.0 |   NA |   NA |   NA | 3.75 | 8.50 | 6.50 | NA  |
|   8 | 1000012 | 6.4 | 6.75 | 7.8 |   NA |   NA |   NA | 5.50 | 7.00 | 7.50 | NA  |
|   9 | 1000011 | 6.0 | 7.75 | 8.2 |   NA |   NA |   NA | 3.00 | 7.25 | 8.50 | NA  |
|  10 | 1000010 | 8.8 | 6.25 | 9.2 | 8.75 | 8.75 | 3.00 |   NA |   NA |   NA | NA  |

In the script, I also use `furrr` package (front-end to the `future`
package) to send request in parallel. The use of parallel yield around 3
times faster result (60 mins for nearly 1 millions result) compare with
normal use.
