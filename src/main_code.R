# Code Summary ------------------------------------------------------------

# Section 0 concerns the loading of the packages and of the data.

# In Section 1, the source data provided by Sqippa is filtered to select only 
# the relevant variables and observations and to remove redundant information.

# In Section 2, the observations in the data set are compressed into 
# day-observations, in order to have equally spaced observations.

# Section 3 consists in additional filtering of the data set.

# In Section 4, all the remaining missing values are imputed.

# Section 5 prepares the data set for the model, adding the lags (1 and 2) of
# the variables.

# Finally, Section 6 contains the training of the XGBoost model and its 
# predictions performed on a test set.





# 0. Load packages and data -----------------------------------------------


# Load packages
library(tidyverse)
library(imputeTS)
library(caret)
library(xgboost)
library(MLmetrics)

# Set working directory
setwd("D:/OneDrive/.../project-smart-emergency-lighting") # change this

# Load the complete data set 
load(file = "Data_Complete.RData")





# 1. General filtering ----------------------------------------------------


# Relevant features
keys <- c(
  # IDs that identify each device 
  "device_id", 
  # time variable
  "metadata_time",
  # voltage of the devices' batteries
  "payload_fields_battery_voltage",
  # intensity of the devices' led
  "payload_fields_led_intensity",
  # temperature registered by the devices' sensors
  "payload_fields_temperature_microcontroller",
  # label that indicates whether there is a failure or not
  "payload_fields_flag")

# We will use the numeric variables (battery voltage, led intensity and
# microcontroller temperature) as predictors of the flag (failure).

clean_sqippa <- as.data.frame(
  sqippa %>%
    # select relevant devices and remove empty observations
    filter(app_id == "sqippa-autogen" &    
             payload_fields_message_type != "" &
             payload_fields_message_type != "shutdown") %>%
    # select relevant columns
    select(all_of(keys)) %>%
    # remove duplicates
    distinct()
)

# Sort the data by devices and time
clean_sqippa <- clean_sqippa[order(clean_sqippa$device_id, 
                                   clean_sqippa$metadata_time),]

# Transform label into 1 and 0
clean_sqippa$payload_fields_flag <- ifelse(is.na(
  clean_sqippa$payload_fields_flag), 0, 1)

# Example - device
device <- filter(clean_sqippa, device_id == unique(clean_sqippa$device_id)[2])
plot(device$metadata_time, device$payload_fields_battery_voltage, type = "l", 
     main = "Battery voltage over time", xlab = "Time", ylab = "Battery voltage")
plot(device$metadata_time, device$payload_fields_led_intensity, type = "l",
     main = "Led intensity over time", xlab = "Time", ylab = "Led intensity")
plot(device$metadata_time, device$payload_fields_temperature_microcontroller, type = "l",
     main = "Temperature over time", xlab = "Time", ylab = "Temperature")

# Failures check
fails_clean <- filter(clean_sqippa, payload_fields_flag == 1)
# number of failures
nrow(fails_clean)
# number of failing devices
length(unique(fails_clean$device_id))

# Structure check
str(clean_sqippa)
head(clean_sqippa)





# 2. Compress observations to days ----------------------------------------


# We create a data frame in which the observations are compressed into
# days, the numeric variables will have the mean of the values while the 
# failures variable will have the max value within the day. Thus, if a day 
# contains at least one observation with a failure, the new day-observation 
# will have a failure.

compressed_days <- as.data.frame(
  clean_sqippa %>%
    # transform the time variable into dates (no hours, minutes and seconds)
    mutate(metadata_time = as.Date(metadata_time)) %>%
    # group by device and day
    group_by(device_id, metadata_time) %>%
    summarize(
      # apply mean function on the three numeric variables
      across(.cols = c("payload_fields_battery_voltage",
                       "payload_fields_led_intensity",
                       "payload_fields_temperature_microcontroller"),
             .fn = mean), 
      # apply max function on the failures variable
      across(.cols = c("payload_fields_flag"),
             .fn = max
      ),
      .groups = "keep")
)

# Here, we create a data frame containing every day for each device (even the 
# ones for which there are no observations in the initial data set) and we left 
# join it with the data frame with the compressed day-observations. This data 
# frame will contain the day-observations values and NAs for the days in which 
# there are no observations.

sqippa_days <- as.data.frame(
  clean_sqippa %>%
    # group by device
    group_by(device_id) %>%
    # create regular period of time in days
    summarize(metadata_time = seq(min(as.Date(metadata_time)),
                                  max(as.Date(metadata_time)), by = 1),
              .groups = "drop_last") %>%
    # left joint the data frame with the compressed observations
    left_join(compressed_days, 
              by = c("device_id","metadata_time"))
)

# Example - device
device <- filter(sqippa_days, device_id == unique(sqippa_days$device_id)[2])
plot(device$metadata_time, device$payload_fields_battery_voltage, type = "l", 
     main = "Battery voltage over time", xlab = "Time", ylab = "Battery voltage")
plot(device$metadata_time, device$payload_fields_led_intensity, type = "l",
     main = "Led intensity over time", xlab = "Time", ylab = "Led intensity")
plot(device$metadata_time, device$payload_fields_temperature_microcontroller, type = "l",
     main = "Temperature over time", xlab = "Time", ylab = "Temperature")

# Example - device with missing values
nas <- filter(sqippa_days, is.na(payload_fields_battery_voltage))
device_na <- filter(sqippa_days, device_id == unique(nas$device_id)[5])
plot(device_na$metadata_time, device_na$payload_fields_battery_voltage, type = "o", 
     main = "Battery voltage over time", xlab = "Time", ylab = "Battery voltage")
plot(device_na$metadata_time, device_na$payload_fields_led_intensity, type = "o",
     main = "Led intensity over time", xlab = "Time", ylab = "Led intensity")
plot(device_na$metadata_time, device_na$payload_fields_temperature_microcontroller, type = "o",
     main = "Temperature over time", xlab = "Time", ylab = "Temperature")

# Failures check
fails_days <- filter(sqippa_days, payload_fields_flag == 1)
nrow(fails_days)
length(unique(fails_days$device_id))

# Structure check
str(sqippa_days)
head(sqippa_days)

# NAs statistics
statsNA(sqippa_days$payload_fields_battery_voltage)





# 3. Additional filtering -------------------------------------------------


# In this section we filter out the devices with less than 4 observations,
# in order to have relevant devices in which we at least two observation with
# non-imputated lagged values. Additionally, with this restriction (more than
# 3) we do not lose relevant failing devices.
# Then, we select only the devices with less than 70% of NAs rate in 
# order to have more accurate imputated values.

sqippa_dense <- as.data.frame(
  sqippa_days %>% 
    group_by(device_id) %>% 
    # Remove devices with less than 4 observations (days)
    filter(length(metadata_time) >= 4) %>%
    # Remove devices with more than 70% of NAs (keeping any failing devices)
    filter(sum(is.na(payload_fields_battery_voltage)) / 
             length(payload_fields_battery_voltage) <= 0.3 |
             any(payload_fields_flag != "0", na.rm = TRUE))) 

# Failures check
fails_dense <- filter(sqippa_dense, payload_fields_flag == 1)
nrow(fails_dense)
length(unique(fails_dense$device_id))

# NAs check
any(is.na(sqippa_dense))


statsNA(sqippa_dense$payload_fields_battery_voltage)


# 4. Imputation -----------------------------------------------------------


# We assume that when we have no information, there are no failures.
# Substitute every NA in payload_fields_flag with 0
sqippa_dense$payload_fields_flag[is.na(sqippa_dense$payload_fields_flag)] <- 0

# For the numeric variables, we choose a Linear Weighted Moving Average as
# imputation method.
sqippa_filled <- as.data.frame(
  sqippa_dense %>% 
    group_by(device_id) %>%
    # apply the function na_ma on each variable
    mutate(
      across(.cols = c(payload_fields_battery_voltage,
                       payload_fields_led_intensity,
                       payload_fields_temperature_microcontroller),
             .fns = na_ma, k = 10, weighting = "linear")
    )
)

# Example - values imputations
device_filled <- filter(sqippa_filled, device_id == unique(nas$device_id)[5])
ggplot_na_imputations(device_na$payload_fields_battery_voltage, 
                      device_filled$payload_fields_battery_voltage,
                      title = "Imputed Values for Battery Voltage",
                      ylab = "Battery Voltage")
ggplot_na_imputations(device_na$payload_fields_led_intensity, 
                      device_filled$payload_fields_led_intensity,
                      title = "Imputed Values for Led Intensity",
                      ylab = "Led Intensity")
ggplot_na_imputations(device_na$payload_fields_temperature_microcontroller, 
                      device_filled$payload_fields_temperature_microcontroller,
                      title = "Imputed Values for Temperature",
                      ylab = "Temperature")

# Failures check
fails_filled <- filter(sqippa_filled, payload_fields_flag == 1)
nrow(fails_filled)
length(unique(fails_filled$device_id))

# NAs check
any(is.na(sqippa_filled))





# 5. Lags -----------------------------------------------------------------


# Data frame with lagged variables (lag 1 and lag 2)
lags <- as.data.frame(
  sqippa_filled %>%
    group_by(device_id) %>%
    # apply lag function to the variables twice (for lag 1 and lag 2)
    summarize(across(.cols = c(payload_fields_battery_voltage,
                               payload_fields_led_intensity,
                               payload_fields_temperature_microcontroller,
                               payload_fields_flag),
                     .fns = list(lag, function(x) lag(x, n = 2))), 
              .groups = "drop_last") %>%
    # drop device_id column
    select(-device_id)
)

# Change columns' names
colnames(lags) <- c(rbind(paste0(colnames(sqippa_filled[, -c(1,2)]), "_lag1"),
                          paste0(colnames(sqippa_filled[, -c(1,2)]), "_lag2")))
# Bind device IDs, time and label to the lagged variables
sqippa_lagged <- cbind("device_id" = sqippa_filled$device_id, 
                       "metadata_time" = sqippa_filled$metadata_time, 
                       "payload_fields_flag" = sqippa_filled$payload_fields_flag,
                       lags)


# Imputation of lags

# Substitute every NA in lagged flag variables with 0
sqippa_lagged$payload_fields_flag_lag1[is.na(sqippa_lagged$payload_fields_flag_lag1)] <- 0
sqippa_lagged$payload_fields_flag_lag2[is.na(sqippa_lagged$payload_fields_flag_lag2)] <- 0

# Impute missing values due to the lag
sqippa_model <- as.data.frame(
  sqippa_lagged %>%
    group_by(device_id) %>%
    # apply moving average imputation function to the variables
    summarise(across(.fns = na_ma, k = 10, weighting = "linear"), 
              .groups = "drop_last")
)

# Failures check
fails_model <- filter(sqippa_model, payload_fields_flag == 1)
nrow(fails_model)
length(unique(fails_model$device_id))

# NA check
any(is.na(sqippa_model))

# Structure check
str(sqippa_model)





# 6. Model ----------------------------------------------------------------


# Select columns for training the model (all except id, time and label)
predictors <- 4:length(sqippa_model)
colnames(sqippa_model[, predictors])

# Partition of the data (75%)
set.seed(12345)
trainIndex <- createDataPartition(sqippa_model$payload_fields_flag, p = .75, 
                                  list = FALSE, 
                                  times = 1)
# Training and test set
train <- sqippa_model[trainIndex, predictors]
test <- sqippa_model[-trainIndex, predictors]
# Training and test set labels
label_train <- sqippa_model$payload_fields_flag[trainIndex]
label_test <- sqippa_model$payload_fields_flag[-trainIndex]
# Create dense matrices for the XGBoost
dtrain <- xgb.DMatrix(as.matrix(train), label = label_train)
dtest <- xgb.DMatrix(as.matrix(test), label = label_test)

# Train the model
model <- xgboost(data = dtrain, 
                 max.depth = 5, 
                 eta = 0.2, 
                 nrounds = 100,
                 objective = "binary:logistic")

# Importance matrix
importance_matrix <- xgb.importance(colnames(dtrain), model = model)
importance_matrix


# Probability on the training set
prob_train <- predict(model, dtrain)
# Prediction of failure based on threshold
threshold <- 0.5
pred_train <- as.numeric(prob_train > threshold)
# Plot of the predicted probabilities
plot(prob_train, type = 'p')
abline(h = threshold, col = 6, lty = 2)
# Confusion matrix
ConfusionMatrix(pred_train, label_train)

# Probability assigned to true failures
options(scipen = 9999)
prob_train[which(label_train == 1)]
# Average probability assigned to true failures
mean(prob_train[which(label_train == 1)])
# Average probability assigned to non failures
mean(prob_train[which(label_train == 0)])


# Probability on the test set
prob_test <- predict(model, dtest)
# Prediction of failure based on threshold
threshold <- 0.5
pred_test <- as.numeric(prob_test > threshold)
# Plot of the predicted probabilities
plot(prob_test, type = 'p')
abline(h = threshold, col = 6, lty = 2)
# Confusion matrix
ConfusionMatrix(pred_test, label_test)

# Probability assigned to true failures
options(scipen = 9999)
prob_test[which(label_test == 1)]
# Average probability assigned to true failures
mean(prob_test[which(label_test == 1)])
# Average probability assigned to non failures
mean(prob_test[which(label_test == 0)])


