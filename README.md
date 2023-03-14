<h1> Smart Emergency Lighting
<img src="https://github.com/quang-phong/project-2-smart-emergency-lighting/blob/main/media/gif/dog-says-hi.gif" width="80px">
</h1>

<img align='right' src="https://github.com/quang-phong/project-2-smart-emergency-lighting/blob/main/media/gif/ceiling-light.gif" width="400px">

[![Linkedin Badge](https://img.shields.io/badge/-@quangphong-0072b1?style=flat&logo=LinkedIn&link=https://www.linkedin.com/in/quangphong/)](https://www.linkedin.com/in/quangphong/) 
[![Github Badge](https://img.shields.io/badge/-@quang--phong-171515?style=flat&logo=github&logoColor=white&link=https://github.com/quang-phong)](https://github.com/quang-phong)
[![Email Badge](https://img.shields.io/badge/-quangtrieuphong@outlook.com-00a2ed?style=flat&logo=microsoftoutlook&logoColor=white&link=mailto:quangtrieuphong@outlook.com)](mailto:quangtrieuphong@outlook.com)


Author: **Quang Phong**  
Year: 2022

## 🧐 What?

The project revolves around the birth of the new service of Light as a Service. "Smart Emergency Lighting" is a project for HBI Emergency Lighting and Sqippa Platform.

## 🤷 Why?  
Due to the market changes and the irruption of IoT technologies, there is an opportunity for HBI to give a turn in emergency light services and offer light as a service to its customers. This innovation comes with several other challenges in the daily tasks that HBI workers need to face to deliver LaaS. To offer an attractive deal to its customers the costs of the service must be kept low in order to have enough margin to sustain
the company. The efficient use by HBI workers of the Sqippa platform plays a key role for this purpose by not only controlling the devices but also exposing them when they fail and need to be replaced. In this line, HBI can act before an incident with a device occurs and stops working. This is a big advancement in terms of customer experience in that users of the
building will never be exposed to damaged security lights risks thanks to HBI’s capacity of acting upfront to components failures repairing and replacing promptly.

In reality, several issues arise in the Sqippa service chain. Sqippa platform is not powerful enough to detect when a device component is going to break. This means that HBI teams act reactively when a component is off, limiting the planning of the journey and replacement work and therefore increasing costs HBI’s customer retention and reputation are also subject to the well functioning of their devices. Damaged security lights violate the safety of the buildings and their occupants. This could potentially lead to receiving a fine from authorities or complaints from inhabitants and in a real endangering situation to more grievous consequences. Responding to the failures in time is key but this is also limited by the fact that HBI does not contact directly with its customers but with intermediaries, limiting the flow of information and the speed of
reaction.

Solutions proposed to HBI for the Sqippa platform aim at enhancing
its analytics capabilities to help the company and its workers address the challenges mentioned above As said, these solutions focus on the data analytics prospects of the platform. This is our conclusion after studying its current situation, which attempts the difficulties Sqippa team faces in the delivery of its service. The solutions proposed are the following:

Predictive model for maintenance based on historical data analysis
1. Early alert of failure events of devices
2. Information about the correlation among the failed components

## ⚒️ How?  
Building a good model capable of predicting maintenance from the preprocessed data is of vital importance. With predictors as microcontroller temperature, battery voltage, and led intensity, we decided to use a machine learning (ML) classification model to predict the dependent variable: failure.

With the aim of optimizing the maintenance procedure, XGBoost is employed as predictive model. Through this model, I want to predict which device will manifest battery or hardware failure within 24 hours after the last observation. This information would help in generating shorter and faster routes for HBI technicians.

## 🧱 Structure?
To protect the confidentality of the data for my customer and avoid violating the agreement, I decide not to make the raw data and cleaned data public here.
This repository contains 3 folders:
- **src**, including: 
- **deliverables**, including:
    + project-summary
    > **Note**  
    > For the full detailed report (study), you can email or leave a message at my LinkedIn.
- **media** (media files)
  
## ✌️ Result?  

Although there are several limitations with the available data, in general, the model is valid. This can be seen by analyzing the importance matrix of the model. From this, it can be said that battery voltage and
microcontroller temperature are critical determinators of emergency light failures. In the test set of the data, the probability of failure assigned by the model to true failure is notably greater than the probability assigned to true non failure (around 300 times bigger). This proves that even with a small number of failures, the model manages to discriminate between the classes successfully. This indicates that the model is applicable and would provide more accurate predictions if additional data is used in training the model.

<p align="center" width="100%">
    <img src="https://github.com/quang-phong/project-2-smart-emergency-lighting/blob/main/media/img/new-process-map.png" width="60%"> <br>  
    <em>Adapted process map for HBI’s maintenance process</em>
</p>

Generally, a process map is proposed to support the sustainable use of our
prediction model as a service. 

After the installer visits the building, examines the devices, and performs maintenance work, the model supervisor will receive actual status (failure or not) to update the model. Values of new observations are added to train the model. Besides that, he/she could inquire about any observable abnormalities of the devices that may be associated with the predicted and the actual values. More importantly, the prediction model might be imperfect at forecasting failures, especially in the early days, thus the manager can possibly receive information about false negative values as well. These are real failures captured by testing but not predicted earlier by the model. Periodically, the supervisor evaluates model performance using its confusion matrix of predicted and actual values. Additionally, he/she recalculates the cost benefit matrix detailing loss and gain for each quadrant of the confusion matrix. Accordingly, he/she makes changes to optimize the failure threshold and fine tune the model. The model then could be iteratively constructed.
Besides the alerts triggered by our model and the remaining lifespan of emergency lights as well as their batteries, results from the failure prediction model can provide additional information for route optimization and investigation decisions. For example, the supervisor can look at an increase in failure probabilities returned from our model of one device, especially ones that are reaching the threshold, to examine whether its microcontroller temperature and battery voltage are having increasingly similar patterns to those having malfunctioned before. This input enables for more flexible and longer term route planning.

## 🪁 Future?
In the future, given that the model can predict failure in a longer time window, the supervisor can try to look for the sweet spot. For example, say it is possible to forecast for 10 days ahead, he/she can optimize how early the devices should be repaired/replaced before their predicted failure time to minimize the costs and the risks at the same time.
