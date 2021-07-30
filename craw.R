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

## Function to find limit student ID of each province
limit_api_point <- function(province_code) {
  
  sbd = 200000L
  i = sbd
  
  while( i > 1) {
    sbd_chr <- paste0(province_code, str_pad(sbd, pad = 0, width = 6))
    i = as.integer(i/2)
    tmp = get_score(sbd_chr)
    if (length(tmp) == 0 ) {
      sbd = sbd - i
    } else {
      sbd = sbd + i
    }
   
  }
  return(sbd + 1L)
}

# test: limit_api_point('02')

# set limit for all province ----------------------------------------------

data <- tibble(province_code = str_pad(seq(1:64), width = 2, pad = 0))

## set up run in parallel
library(furrr)
plan(multisession, workers = 7)

data <- data %>% 
  mutate(max_api = future_map_int(province_code, limit_api_point, .progress = TRUE))




# craw data ---------------------------------------------------------------

# prepare function to request data from API
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

# Let get_score2() handle error 
get_score2_safe <- possibly(get_score2, otherwise = NA_character_)

# Because API allow to receive max ~300 result, I modify sbd to get 100 result each request
# example: request sbd = '010001__' will yield result from '01000100' to '01000199'

input_API <- data %>%
  # remove province 20 ( no  province 20, maybe that ID is for Ha Tay)
  filter(province_code != '20') %>% 
  mutate(max_api = str_sub(max_api,1, -3)) %>% 
  mutate(sbd = map(max_api, ~ 0:.x)) %>% 
  unnest(cols = sbd) %>% 
  mutate(sbd = str_pad(sbd,width = 4, pad = 0 , side = 'left')) %>% 
  mutate(sbd = paste0(province_code, sbd))


# send API in parallel ----------------------------------------------------

library(furrr)
plan(multisession, workers = 4)
output_data <- input_API %>%   
  mutate(result = future_map(sbd, 
                             get_score2_safe,
                             .progress = TRUE))

# take around 60 mins

# read tab separated data to data frame
plan(multisession, workers = 4)

output_data <- output_data %>% 
  filter(!is.na(result)) %>% 
  unnest(result) %>% 
  # add "\n" to make fread realize the TSV format
  mutate(result = paste0(result, "\n")) %>% 
  mutate(result = future_map(result, ~data.table::fread(.x,))) %>% 
  unnest(result)


col_names <- c('toan', 'van', 'nn', 'li', 'hoa','sinh', 'su', 'dia', 'gdcd')

result <- output_data %>% 
  rename_with(.fn = ~col_names, .cols = V3:V11) %>% 
  select(-V12,-V1, - max_api, -sbd)

## write data to rds and csv
fs::dir_create("data")
write_csv(result, "data/output.csv")
write_rds(result, "data/output.rds")

 




