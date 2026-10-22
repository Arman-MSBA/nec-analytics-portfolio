# Extracted from analysis.Rmd; run from this project folder.

# Run from this project folder; data are supplied separately.
root <- normalizePath('.', winslash='/')
library(data.table)
library(ranger)
library(xgboost)
library(e1071)
library(jsonlite)
knitr::opts_chunk$set(echo=TRUE,message=FALSE,warning=TRUE,error=FALSE,
                     fig.width=6.3,fig.height=3.7,dpi=180)
options(width=90,digits=5,scipen=8)
setDTthreads(4)
results <- file.path(root,'results')
dir.create(results,showWarnings=FALSE,recursive=TRUE)
seed <- 691006L
# Define identical evaluation measures for every probability forecast.
loss <- function(y,p) {p<-pmin(pmax(p,1e-15),1-1e-15);-mean(y*log(p)+(1-y)*log(1-p))}
auc <- function(y,p) {n1<-sum(y==1);n0<-sum(y==0);(sum(rank(p)[y==1])-n1*(n1+1)/2)/(n1*n0)}
measure <- function(y,p,cut=.5) {
 z<-as.integer(p>=cut);tp<-sum(z==1 & y==1);tn<-sum(z==0 & y==0)
 fp<-sum(z==1 & y==0);fn<-sum(z==0 & y==1)
 pr<-if(tp+fp)tp/(tp+fp) else 0;re<-tp/(tp+fn)
 c(Log_loss=loss(y,p),AUC=auc(y,p),Accuracy=mean(z==y),Precision=pr,Recall=re,
   F1=if(pr+re)2*pr*re/(pr+re) else 0,TP=tp,TN=tn,FP=fp,FN=fn)
}
tab <- function(x,digits=4) knitr::kable(x,digits=digits,row.names=FALSE)

# Use the labeled course file, never the unlabeled Kaggle customer test file.
data_path <- file.path(root,'data','train.csv')
dat <- fread(data_path)
features <- grep('^var_',names(dat),value=TRUE)
stopifnot(nrow(dat)==200000L,length(features)==200L,
          all(dat$target %in% 0:1),!anyDuplicated(dat$ID_code))
checks <- data.frame(Customers=nrow(dat),Predictors=length(features),
 Positive=sum(dat$target),Positive_percent=100*mean(dat$target),Missing_cells=sum(is.na(dat)))
tab(checks)

# Reserve 20% of each class for validation and a separate 20% for testing.
# Keep all four algorithms on exactly 6,000 common fitting rows, matching
# the earlier SVM resource budget instead of giving the forests more rows.
set.seed(seed)
fit_idx<-val_idx<-test_idx<-integer()
for(cl in 0:1) {
 ids<-sample(which(dat$target==cl)); n<-length(ids); nv<-floor(.2*n)
 val_idx<-c(val_idx,ids[seq_len(nv)])
 test_idx<-c(test_idx,ids[nv+seq_len(nv)])
 pool<-ids[(2*nv+1L):n]
 nf<-if(cl==1)603L else 5397L
 fit_idx<-c(fit_idx,pool[seq_len(nf)])
}
stopifnot(!length(intersect(fit_idx,val_idx)),!length(intersect(fit_idx,test_idx)),
          !length(intersect(val_idx,test_idx)))
# Learn imputation and scaling from fitting rows only.
x<-as.matrix(dat[,..features]);y<-dat$target
med<-apply(x[fit_idx,,drop=FALSE],2,median,na.rm=TRUE)
stopifnot(all(is.finite(med)))
for(j in seq_along(features)) x[is.na(x[,j]),j]<-med[j]
center<-colMeans(x[fit_idx,,drop=FALSE]);spread<-apply(x[fit_idx,,drop=FALSE],2,sd)
stopifnot(all(is.finite(spread)),all(spread>0))
z<-scale(x,center=center,scale=spread)
membership<-rep('Not used for fitting or evaluation',nrow(dat))
membership[fit_idx]<-'Training';membership[val_idx]<-'Validation';membership[test_idx]<-'Test'
fwrite(data.table(ID_code=dat$ID_code,Partition=membership),file.path(results,'split_membership.csv'))
split_table<-data.frame(Partition=c('Training','Validation','Test','Unused'),
 Rows=c(length(fit_idx),length(val_idx),length(test_idx),sum(grepl('Not used',membership))),
 Positive=c(sum(y[fit_idx]),sum(y[val_idx]),sum(y[test_idx]),sum(y[grepl('Not used',membership)])))
split_table$Positive_percent<-100*split_table$Positive/split_table$Rows
tab(split_table)
# Reuse completed fits only when code, input data, packages, and split IDs match.
# Delete verified_execution_cache.rds to force all four models to refit.
signature<-list(code=unname(tools::md5sum(file.path(root,'analysis.Rmd'))),
 data=unname(tools::md5sum(data_path)),seed=seed,fit=fit_idx,val=val_idx,test=test_idx,
 versions=sapply(c('ranger','e1071','xgboost'),function(p)as.character(packageVersion(p))))
cache_file<-file.path(results,'verified_execution_cache.rds')
cached<-if(file.exists(cache_file))readRDS(cache_file) else NULL
use_cache<-!is.null(cached) && identical(cached$signature,signature)

# Store every final fitting choice explicitly rather than relying on defaults.
settings<-data.frame(Algorithm=c('Logistic regression','SVM','Random Forest','XGBoost'),
 Prior_choice=c('Top 50 linear','M09','RF06','XGB03'),
 Final_settings=c('Binomial logit; intercept; 50 screened linear predictors; no penalty; maxit 50',
 'Radial C classification; C 0.01; gamma 0.005; inverse frequency class weights; tolerance 0.001',
 'Probability forest; 500 trees; mtry 40; min.node.size 30; Gini; bootstrap fraction 1',
 'Binary logistic; depth 4; eta 0.10; 600 rounds; subsample 1; colsample 1; min child weight 1; lambda 1; alpha 0; gamma 0; hist'))
tab(settings)

# Rank associations only inside the common fitting sample and retain 50 fields.
correlations<-apply(z[fit_idx,,drop=FALSE],2,function(v)cor(v,y[fit_idx]))
top50<-names(sort(abs(correlations),decreasing=TRUE))[1:50]
logistic_frame<-data.frame(target=y[fit_idx],z[fit_idx,top50,drop=FALSE])
logistic_fit<-if(use_cache)cached$models$logistic else glm(target~.,data=logistic_frame,family=binomial(),
                  control=glm.control(maxit=50))
stopifnot(logistic_fit$converged,all(is.finite(coef(logistic_fit))))
lp<-function(idx)as.numeric(predict(logistic_fit,newdata=data.frame(z[idx,top50,drop=FALSE]),type='response'))
fwrite(data.table(Predictor=top50,Training_correlation=correlations[top50]),file.path(results,'logistic_predictors.csv'))
cat('Logistic model converged:',logistic_fit$converged,'\nPredictors:',length(top50),'\n')

# Fit the previously selected SVM on the same rows as all other algorithms.
weights<-6000/(2*table(factor(y[fit_idx],levels=0:1)))
set.seed(seed)
svm_fit<-if(use_cache)cached$models$svm else svm(x=z[fit_idx,,drop=FALSE],y=factor(y[fit_idx],levels=0:1),
 type='C-classification',kernel='radial',cost=.01,gamma=.005,
 class.weights=weights,scale=FALSE,probability=FALSE,tolerance=.001,
 cachesize=400,shrinking=TRUE)
# Orient the raw margin toward class 1 using the libsvm level convention.
score<-function(idx) {
 pred<-predict(svm_fit,z[idx,,drop=FALSE],decision.values=TRUE)
 raw<-as.numeric(attr(pred,'decision.values'))
 if(svm_fit$levels[svm_fit$labels[1]]=='1')raw else -raw
}
# Cache includes scores in the verified partition order to avoid costly reruns.
if(use_cache) {
 s_train<-cached$margins$train;s_val<-cached$margins$validation;s_test<-cached$margins$test
} else {s_train<-score(fit_idx);s_val<-score(val_idx);s_test<-score(test_idx)}
# Fit a two-coefficient probability mapping only on validation observations.
calibration<-glm(outcome~margin,data=data.frame(outcome=y[val_idx],margin=s_val),family=binomial())
stopifnot(calibration$converged,all(is.finite(coef(calibration))))
sp<-function(s)as.numeric(predict(calibration,newdata=data.frame(margin=s),type='response'))
tab(data.frame(Term=names(coef(calibration)),Coefficient=as.numeric(coef(calibration))))
cat('Support vectors:',svm_fit$tot.nSV,'\n')

# Refit RF06 with the frozen Week 5 settings and identical fitting rows.
rf_fit<-if(use_cache)cached$models$forest else ranger(x=x[fit_idx,,drop=FALSE],y=factor(y[fit_idx],levels=0:1),
 probability=TRUE,num.trees=500,mtry=40,min.node.size=30,splitrule='gini',
 replace=TRUE,sample.fraction=1,importance='none',num.threads=4,seed=seed)
rp<-function(idx)as.numeric(predict(rf_fit,x[idx,,drop=FALSE],num.threads=4)$predictions[,'1'])
cat('Forest trees:',rf_fit$num.trees,'\nmtry:',rf_fit$mtry,'\n')

# Fit exactly the prior selected 600 rounds, without test-based early stopping.
xgb_params<-list(objective='binary:logistic',eval_metric='logloss',max_depth=4,
 eta=.1,subsample=1,colsample_bytree=1,min_child_weight=1,lambda=1,alpha=0,
 gamma=0,tree_method='hist',nthread=4,seed=seed,scale_pos_weight=1,max_bin=256)
dtrain<-xgb.DMatrix(x[fit_idx,,drop=FALSE],label=y[fit_idx])
dval<-xgb.DMatrix(x[val_idx,,drop=FALSE],label=y[val_idx])
if(use_cache && !is.null(cached$history) && nrow(cached$history)==600L) {
 xgb_fit<-xgb.load(file.path(results,'xgboost.ubj'))
 xgb_history<-cached$history
} else {
 xgb_fit<-xgb.train(params=xgb_params,data=dtrain,nrounds=600,
  evals=list(train=dtrain,validation=dval),verbose=0)
 # XGBoost 3.2 stores evaluation history as an R attribute, not a list field.
 xgb_history<-as.data.frame(attr(xgb_fit,'evaluation_log'))
}
xp<-function(idx)as.numeric(predict(xgb_fit,xgb.DMatrix(x[idx,,drop=FALSE])))
stopifnot(nrow(xgb_history)==600L,all(c('train_logloss','validation_logloss') %in% names(xgb_history)))
cat('Boosting rounds:',nrow(xgb_history),'\n')

# Collect probabilities in the same row order for each shared partition.
probs_train<-list(Logistic=lp(fit_idx),SVM=sp(s_train),Random_Forest=rp(fit_idx),XGBoost=xp(fit_idx))
probs_val<-list(Logistic=lp(val_idx),SVM=sp(s_val),Random_Forest=rp(val_idx),XGBoost=xp(val_idx))
probs_test<-list(Logistic=lp(test_idx),SVM=sp(s_test),Random_Forest=rp(test_idx),XGBoost=xp(test_idx))
base_probability<-mean(y[fit_idx]);base_test<-loss(y[test_idx],rep(base_probability,length(test_idx)))
test_table<-rbindlist(lapply(names(probs_test),function(n) {
 p<-probs_test[[n]];stopifnot(length(p)==length(test_idx),all(is.finite(p)),all(p>=0 & p<=1))
 as.data.table(c(list(Model=n),as.list(measure(y[test_idx],p,.5))))
}))
test_table[,Reduction_percent:=100*(base_test-Log_loss)/base_test]
cost_table<-data.frame(Model=names(probs_test),
 Training_loss=sapply(probs_train,function(p)loss(y[fit_idx],p)),
 Validation_loss=sapply(probs_val,function(p)loss(y[val_idx],p)),
 Test_loss=test_table$Log_loss,Test_reduction_percent=test_table$Reduction_percent)
tab(cost_table)
tab(test_table[,.(Model,Accuracy,AUC,Precision,Recall,F1)])
winner<-test_table$Model[which.min(test_table$Log_loss)]
accuracy_winner<-test_table$Model[which.max(test_table$Accuracy)]

# Display shared predictive cost and accuracy in separate, labeled panels.
par(mfrow=c(1,2),mar=c(7,4,2,1))
labels<-c('Logistic','SVM','Forest','XGBoost')
barplot(test_table$Log_loss,names.arg=labels,las=2,col='gray65',ylim=c(0,max(base_test,test_table$Log_loss)*1.15),
 ylab='Test binary log loss',main='Probability cost')
abline(h=base_test,lty=2);legend('topright','Constant forecast',lty=2,bty='n',cex=.75)
barplot(100*test_table$Accuracy,names.arg=labels,las=2,col='steelblue',ylim=c(0,100),
 ylab='Test accuracy percent',main='Cutoff 0.50')
abline(h=100*mean(y[test_idx]==0),lty=2)
par(mfrow=c(1,1))

# Show all four outcomes for each model at the identical 0.50 threshold.
tab(test_table[,.(Model,TP,TN,FP,FN)],digits=0)
# Select an optional F1 cutoff on validation only, never using test labels.
cutoffs<-sapply(probs_val,function(p) {
 grid<-seq(.01,.80,.01);f<-sapply(grid,function(t)measure(y[val_idx],p,t)['F1'])
 grid[which.max(f)]
})
cutoff_table<-rbindlist(lapply(names(probs_test),function(n)
 as.data.table(c(list(Model=n,Cutoff=cutoffs[[n]]),as.list(measure(y[test_idx],probs_test[[n]],cutoffs[[n]]))))))
tab(cutoff_table[,.(Model,Cutoff,Accuracy,Precision,Recall,F1,TP,FP,FN)])

# Sort each test forecast and compute exact cumulative ROC coordinates.
colors<-c('black','steelblue','darkorange3','firebrick')
plot(c(0,1),c(0,1),type='n',xlab='False positive rate',ylab='True positive rate',main='Common test ROC curves')
abline(0,1,lty=2,col='gray60')
for(i in seq_along(probs_test)) {
 p<-probs_test[[i]];ord<-order(p,decreasing=TRUE);yy<-y[test_idx][ord]
 ends<-which(!duplicated(p[ord],fromLast=TRUE))
 lines(c(0,cumsum(yy==0)[ends]/sum(yy==0),1),
       c(0,cumsum(yy==1)[ends]/sum(yy==1),1),col=colors[i],lwd=2)
}
legend('bottomright',paste(labels,'AUC',sprintf('%.3f',test_table$AUC)),col=colors,lwd=2,bty='n',cex=.8)

# Show whether adding frozen boosting rounds transfers to validation rows.
history<-xgb_history
# Summarize and sort calibration groups before connecting their plotted points.
cal_rows<-list()
for(i in seq_along(probs_test)) {
 p<-probs_test[[i]];groups<-pmin(10,ceiling(rank(p,ties.method='first')/length(p)*10))
 b<-data.table(p=p,y=y[test_idx],group=groups)[,.(Predicted=mean(p),Observed=mean(y),Rows=.N),by=group]
 setorder(b,group);b[,Model:=names(probs_test)[i]];cal_rows[[i]]<-b
}
calibration_table<-rbindlist(cal_rows)
calibration_limit<-ceiling(10*max(calibration_table$Predicted,calibration_table$Observed))/10+.05
par(mfrow=c(1,2),mar=c(4,4,2,1))
matplot(seq_len(nrow(history)),history[,c('train_logloss','validation_logloss')],type='l',lty=1,
 col=c('black','firebrick'),xlab='Boosting round',ylab='Binary log loss',main='XGBoost learning')
legend('bottomleft',c('Training','Validation'),col=c('black','firebrick'),lty=1,bty='n',cex=.7)
# Use deciles of each model's own scores for a descriptive test calibration plot.
plot(c(0,calibration_limit),c(0,calibration_limit),type='n',xlab='Mean predicted probability',ylab='Observed positive fraction',main='Test calibration')
abline(0,1,lty=2,col='gray60')
for(i in seq_along(probs_test)) {
 b<-cal_rows[[i]]
 lines(b$Predicted,b$Observed,type='b',col=colors[i],pch=i,lwd=1.5)
}
legend('topleft',labels,col=colors,pch=1:4,lty=1,bty='n',cex=.7)
par(mfrow=c(1,1))
tab(data.frame(First_training_loss=history$train_logloss[1],Final_training_loss=tail(history$train_logloss,1),
 First_validation_loss=history$validation_logloss[1],Final_validation_loss=tail(history$validation_logloss,1)))

# Save actual model outputs and row IDs so every reported number is auditable.
fwrite(test_table,file.path(results,'test_metrics.csv'))
fwrite(as.data.table(cost_table),file.path(results,'cost_comparison.csv'))
fwrite(cutoff_table,file.path(results,'selected_cutoff_metrics.csv'))
fwrite(rbindlist(cal_rows),file.path(results,'calibration_groups.csv'))
fwrite(data.table(ID_code=dat$ID_code[test_idx],target=y[test_idx],
 as.data.table(probs_test)),file.path(results,'test_predictions.csv'))
# Remove formula environments before saving to avoid serializing the entire
# analysis workspace through glm terms. This does not change predictions.
compact_glm<-function(m) {
 attr(m$terms,'.Environment')<-baseenv();environment(m$formula)<-baseenv()
 attr(m$model,'terms')<-NULL
 # The default binomial link is logit. Recreate its closures without retaining
 # an unevaluated link argument that can capture the entire knitting workspace.
 m$family<-stats::binomial();m
}
logistic_fit<-compact_glm(logistic_fit);calibration<-compact_glm(calibration)
models_to_save<-list(logistic=logistic_fit,svm=svm_fit,svm_calibration=calibration,forest=rf_fit,
 top50=top50,medians=med,centers=center,scales=spread,cutoffs=cutoffs,seed=seed)
saveRDS(models_to_save,file.path(results,'fitted_models.rds'))
saveRDS(list(signature=signature,models=models_to_save,
 margins=list(train=s_train,validation=s_val,test=s_test),history=xgb_history),cache_file)
xgb.save(xgb_fit,file.path(results,'xgboost.ubj'))
saveRDS(list(costs=cost_table,test=test_table,cutoff=cutoff_table,settings=settings,
 checks=checks,splits=split_table,winner=winner,history=history,
 calibration=coef(calibration)),file.path(results,'report_results.rds'))
write_json(list(costs=cost_table,test=test_table,cutoff=cutoff_table,settings=settings,
 checks=checks,splits=split_table,winner=winner,calibration=as.list(coef(calibration))),
 file.path(results,'summary.json'),pretty=TRUE,auto_unbox=TRUE,digits=12)
cat('All four selected models fitted and evaluated successfully.\n')
cat('Seed:',seed,'\nData MD5:',unname(tools::md5sum(data_path)),'\n')
print(sessionInfo())
