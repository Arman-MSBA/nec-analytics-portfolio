# Extracted from analysis.Rmd; run from this project folder.

# Avoid the cli background-thread shutdown problem under Windows ARM emulation.
Sys.setenv(CLI_NO_THREAD='true')
# Run from this project folder; obtain data separately.
assignment_dir <- normalizePath('.', winslash='/')
results_dir <- file.path(assignment_dir, 'results')
dir.create(results_dir, showWarnings=FALSE)
# Load glmnet without trying to replace Matrix already used by mgcv.
# All glmnet functions below use glmnet::, so attaching packages is unnecessary.
if (!requireNamespace('glmnet', quietly=TRUE)) {
 stop('glmnet could not be loaded. Restart R, then run this setup chunk first.')
}
knitr::opts_chunk$set(echo=TRUE, error=FALSE, message=FALSE, warning=TRUE, comment=NA,
 fig.path='results/figures/', fig.width=6.6, fig.height=3.8, dpi=180,
 dev.args=list(type='cairo'))
options(scipen=8, digits=5)
seed <- 20261019L
fmt <- function(x, digits=2) formatC(x, format='f', digits=digits, big.mark=',')
tab <- function(x) knitr::kable(x, format='pipe', row.names=FALSE)
metric <- function(y, p) c(MSE=mean((y-p)^2), RMSE=sqrt(mean((y-p)^2)),
 MAE=mean(abs(y-p)), R2=1-sum((y-p)^2)/sum((y-mean(y))^2))
newpage <- function() cat('\n```{=openxml}\n<w:p><w:r><w:br w:type="page"/></w:r></w:p>\n```\n')
blue <- '#345F85'; red <- '#A04E42'; green <- '#4D7861'

# Check the same course export used in the earlier Nutrition assignments.
input <- file.path(assignment_dir, 'data', 'Final_Nutrition2.csv')
stopifnot(unname(tools::md5sum(input)) == '7194dac8f4ceb0aea3de143001ac2ea6')
foods <- read.csv(input, check.names=FALSE, stringsAsFactors=FALSE,
 na.strings=c('', 'NA'), colClasses=c(NDB_No='character'))
stopifnot(nrow(foods)==8789L, ncol(foods)==42L,
 !anyNA(foods$Energ_Kcal), !anyDuplicated(foods$NDB_No))
# Keep measured nutrients. Exclude identifiers, descriptions and portion weights.
numeric_fields <- names(foods)[vapply(foods, is.numeric, logical(1))]
predictors <- setdiff(numeric_fields, c('Energ_Kcal','GmWt_1','GmWt_2','NDB_No'))
stopifnot(length(predictors)==33L, !'Energ_Kcal' %in% predictors)
foods$FdGrp_Desc <- factor(foods$FdGrp_Desc)
# Stratify the fixed 80/20 split by food group, keeping all records and all groups.
set.seed(seed)
partition <- rep('Test', nrow(foods))
for (ids in split(seq_len(nrow(foods)), foods$FdGrp_Desc)) {
 chosen <- sample(ids, floor(.8*length(ids)))
 partition[chosen] <- 'Development'
}
dev_raw <- foods[partition=='Development', ]
test_raw <- foods[partition=='Test', ]
stopifnot(all(table(dev_raw$FdGrp_Desc)>0L), all(table(test_raw$FdGrp_Desc)>0L))
# Use identical stratified folds for every alpha and lambda comparison.
set.seed(seed+1L)
fold_id <- integer(nrow(dev_raw))
for (ids in split(seq_len(nrow(dev_raw)), dev_raw$FdGrp_Desc)) {
 fold_id[ids] <- sample(rep(seq_len(5L), length.out=length(ids)))
}
membership <- data.frame(NDB_No=foods$NDB_No, Partition=partition, CV_fold=NA_integer_)
membership$CV_fold[partition=='Development'] <- fold_id
write.csv(membership, file.path(results_dir,'split_and_folds.csv'), row.names=FALSE)
tab(data.frame(Item=c('Food records','Recorded fields','Nutrient predictors',
 'Food groups','Development foods','Held out test foods','CV folds'),
 Value=c(nrow(foods),ncol(foods),length(predictors),nlevels(foods$FdGrp_Desc),
 nrow(dev_raw),nrow(test_raw),length(unique(fold_id)))))

# Learn medians, indicator terms and usable columns from fitting rows only.
prep_fit <- function(raw) {
 med <- vapply(raw[predictors], median, numeric(1), na.rm=TRUE)
 stopifnot(all(is.finite(med)))
 recipe <- list(medians=med,
  indicators=predictors[vapply(raw[predictors], anyNA, logical(1))],
  groups=levels(raw$FdGrp_Desc), columns=NULL)
 x <- prep_apply(raw, recipe)
 # Remove constant columns using fitting rows, not the evaluation partition.
 recipe$columns <- colnames(x)[apply(x,2L,function(z) diff(range(z))>0)]
 recipe
}
prep_apply <- function(raw, recipe) {
 out <- raw[predictors]
 for (v in predictors) {
  if (v %in% recipe$indicators) out[[paste0(v,'_missing')]] <- as.integer(is.na(out[[v]]))
  out[[v]][is.na(out[[v]])] <- recipe$medians[v]
 }
 out$FdGrp_Desc <- factor(raw$FdGrp_Desc, levels=recipe$groups)
 stopifnot(!anyNA(out))
 x <- model.matrix(~., data=out)[,-1L,drop=FALSE]
 if (!is.null(recipe$columns)) x <- x[,recipe$columns,drop=FALSE]
 stopifnot(all(is.finite(x)))
 x
}
# This recipe is for the eventual full-development refits, not reused inside CV.
final_recipe <- prep_fit(dev_raw)
x_dev <- prep_apply(dev_raw, final_recipe)
y_dev <- dev_raw$Energ_Kcal
prep <- data.frame(Predictor=predictors,
 Missing_development=vapply(dev_raw[predictors],function(v) sum(is.na(v)),integer(1)),
 Development_median=unname(final_recipe$medians))
write.csv(prep,file.path(results_dir,'development_preprocessing.csv'),row.names=FALSE)
cat('Final development design columns:', ncol(x_dev), '\n')
cat('Nutrients with missingness indicators:', length(final_recipe$indicators), '\n')
cat('Reference food group:', final_recipe$groups[1], '\n')

# Predeclare 11 alpha values and 101 strictly positive lambda values.
alphas <- seq(0,1,by=.1)
lambdas <- 10^seq(4,-4,length.out=101L)
model_name <- function(a) ifelse(a==0,'Ridge',ifelse(a==1,'LASSO','Elastic Net'))
tab(data.frame(Technique=c('Ridge','LASSO','Elastic Net'),
 Alpha=c('0','1','0.1 to 0.9 by 0.1'),
 Lambda_grid=rep('101 values from 0.0001 to 10000',3),
 Selection=rep('Lowest five fold out of fold MSE',3)))
# Fit the complete declared path rather than silently stopping before its end.
glmnet::glmnet.control(fdev=0, devmax=1)
fit_path <- function(x,y,a) glmnet::glmnet(x,y,family='gaussian',alpha=a,
 lambda=lambdas,standardize=TRUE,intercept=TRUE,
 control=list(thresh=1e-10,maxit=1000000L),penalty.factor=rep(1,ncol(x)))

# Each fold has its own preprocessing recipe and coefficient estimates.
fold_mse <- array(NA_real_,dim=c(length(alphas),length(lambdas),5L))
fold_nonzero <- fold_mse
fold_n <- as.integer(table(factor(fold_id,levels=1:5)))
mean_fold_mse <- numeric(5L)
fold_recipes <- vector('list',5L)
for (k in seq_len(5L)) {
 fit_raw <- dev_raw[fold_id!=k, ]; val_raw <- dev_raw[fold_id==k, ]
 rec <- prep_fit(fit_raw); fold_recipes[[k]] <- rec
 xf <- prep_apply(fit_raw,rec); xv <- prep_apply(val_raw,rec)
 yf <- fit_raw$Energ_Kcal; yv <- val_raw$Energ_Kcal
 mean_fold_mse[k] <- mean((yv-mean(yf))^2)
 for (i in seq_along(alphas)) {
  fit <- fit_path(xf,yf,alphas[i])
  stopifnot(fit$jerr==0L,length(fit$lambda)==length(lambdas))
  p <- as.matrix(predict(fit,newx=xv,s=lambdas))
  fold_mse[i,,k] <- colMeans((p-yv)^2)
  fold_nonzero[i,,k] <- fit$df
 }
 message('Completed cross validation fold ',k,' of 5')
}
# Weight validation folds by size, giving every development food equal weight.
cv_mse <- apply(fold_mse,c(1,2),function(v) weighted.mean(v,fold_n))
cv_se <- apply(fold_mse,c(1,2),function(v) sd(v)/sqrt(5))
mean_cv <- weighted.mean(mean_fold_mse,fold_n)
grid_results <- do.call(rbind,lapply(seq_along(alphas),function(i)
 data.frame(Technique=model_name(alphas[i]),Alpha=alphas[i],Lambda=lambdas,
 CV_MSE=cv_mse[i,],CV_SE=cv_se[i,],CV_RMSE=sqrt(cv_mse[i,]),
 Mean_nonzero=rowMeans(fold_nonzero[i,,]))))
# Freeze the best lambda for every alpha without evaluating the test response.
best_by_alpha <- do.call(rbind,lapply(seq_along(alphas),function(i) {
 j <- which.min(cv_mse[i,]); eligible <- which(cv_mse[i,]<=cv_mse[i,j]+cv_se[i,j])
 data.frame(Technique=model_name(alphas[i]),Alpha=alphas[i],Lambda=lambdas[j],
  CV_MSE=cv_mse[i,j],CV_SE=cv_se[i,j],CV_RMSE=sqrt(cv_mse[i,j]),
  Lambda_1se=max(lambdas[eligible]))
}))
elastic <- best_by_alpha[best_by_alpha$Alpha>0 & best_by_alpha$Alpha<1,]
selected <- rbind(best_by_alpha[best_by_alpha$Alpha==1,],
 best_by_alpha[best_by_alpha$Alpha==0,],elastic[which.min(elastic$CV_MSE),])
rownames(selected) <- NULL
preferred <- which.min(selected$CV_MSE)
display <- best_by_alpha[c('Technique','Alpha','Lambda','CV_MSE','CV_RMSE')]
display[-1] <- lapply(display[-1],function(x) signif(x,5))
tab(display)
write.csv(grid_results,file.path(results_dir,'all_1111_cv_settings.csv'),row.names=FALSE)
write.csv(best_by_alpha,file.path(results_dir,'best_by_alpha.csv'),row.names=FALSE)
write.csv(selected,file.path(results_dir,'selected_hyperparameters.csv'),row.names=FALSE)
saveRDS(list(recipes=fold_recipes,fold_mse=fold_mse,fold_n=fold_n,
 alphas=alphas,lambdas=lambdas,fold_id=fold_id),file.path(results_dir,'cv_evidence.rds'))

# Show full paths on a logarithmic error scale so small and large losses are visible.
colors <- c(blue,red,green)
idx <- match(selected$Alpha,alphas)
yr <- range(cv_mse[idx,])
par(mar=c(5.8,6.5,1.5,1),mgp=c(3.5,1,0),las=1,cex.axis=.85)
plot(log10(lambdas),cv_mse[idx[1],],type='l',log='y',col=colors[1],lwd=2,
 xlab='log10 lambda',ylab='Out of fold MSE on log scale',ylim=yr)
for(i in 2:3) lines(log10(lambdas),cv_mse[idx[i],],col=colors[i],lwd=2,lty=i)
points(log10(selected$Lambda),selected$CV_MSE,pch=19,col=colors,cex=1.1)
abline(h=mean_cv,col='gray45',lty=4)
legend('topleft',c(paste0(selected$Technique,' alpha ',selected$Alpha),'Mean baseline'),
 col=c(colors,'gray45'),lty=c(1,2,3,4),lwd=2,bty='n',cex=.8)

# Refit the frozen settings on all development foods and save deployable recipes.
models <- list(); one_se_models <- list()
for(i in seq_len(nrow(selected))) {
 path <- fit_path(x_dev,y_dev,selected$Alpha[i])
 stopifnot(path$jerr==0L)
 models[[selected$Technique[i]]] <- path
 b <- as.matrix(coef(path,s=selected$Lambda[i]))[-1,1]
 b1 <- as.matrix(coef(path,s=selected$Lambda_1se[i]))[-1,1]
 selected$Nonzero[i] <- sum(abs(b)>1e-8)
 selected$Nonzero_1se[i] <- sum(abs(b1)>1e-8)
 selected$Boundary[i] <- selected$Lambda[i] %in% range(lambdas)
}
settings <- selected[c('Technique','Alpha','Lambda','Lambda_1se','Nonzero','Nonzero_1se')]
settings$Lambda <- signif(settings$Lambda,7)
settings$Lambda_1se <- signif(settings$Lambda_1se,7)
tab(settings)
write.csv(selected,file.path(results_dir,'final_settings.csv'),row.names=FALSE)
saveRDS(list(models=models,settings=selected,recipe=final_recipe,
 predictors=predictors,seed=seed),file.path(results_dir,'final_models.rds'))
# A boundary minimum would limit the claim that the tried range was adequate.
cat('Selected minima at a lambda grid boundary:',sum(selected$Boundary),'\n')

# Only now transform the held-out predictors and evaluate the three frozen models.
x_test <- prep_apply(test_raw,final_recipe)
y_test <- test_raw$Energ_Kcal
predictions <- data.frame(NDB_No=test_raw$NDB_No,Observed=y_test,
 Mean=rep(mean(y_dev),length(y_test)))
for(i in seq_len(nrow(selected))) {
 n <- selected$Technique[i]
 predictions[[n]] <- as.numeric(predict(models[[n]],newx=x_test,s=selected$Lambda[i]))
}
test_metrics <- do.call(rbind,lapply(c('Mean',selected$Technique),function(n)
 data.frame(Technique=n,as.list(metric(y_test,predictions[[n]])),
 Negative_predictions=sum(predictions[[n]]<0),check.names=FALSE)))
test_metrics$Reduction_vs_mean_pct <- 100*(test_metrics$MSE[1]-test_metrics$MSE)/test_metrics$MSE[1]
printed <- test_metrics[c('Technique','MSE','RMSE','MAE','R2')]
printed[-1] <- lapply(printed[-1],function(z) round(z,3))
printed$R2 <- sprintf('%.4f',test_metrics$R2)
tab(printed)
write.csv(test_metrics,file.path(results_dir,'held_out_metrics.csv'),row.names=FALSE)
write.csv(predictions,file.path(results_dir,'held_out_predictions.csv'),row.names=FALSE)
chosen_name <- selected$Technique[preferred]
chosen_row <- test_metrics[test_metrics$Technique==chosen_name,]

# Diagnose the CV-selected model without changing its settings based on test errors.
pred <- predictions[[chosen_name]]; residual <- y_test-pred
par(mfrow=c(1,2),mar=c(4.4,4.4,2.1,1),las=1)
plot(y_test,pred,pch=16,cex=.45,col=adjustcolor(blue,.3),
 xlab='Observed kcal per 100 g',ylab='Predicted kcal per 100 g',main=chosen_name)
abline(0,1,col=red,lty=2,lwd=1.5)
plot(pred,residual,pch=16,cex=.45,col=adjustcolor(blue,.3),
 xlab='Predicted kcal per 100 g',ylab='Observed minus predicted',main='Residual pattern')
abline(h=0,col=red,lty=2);lines(lowess(pred,residual),col='black',lwd=1.5)
par(mfrow=c(1,1))
large <- head(order(abs(residual),decreasing=TRUE),5L)
errors <- data.frame(Food=substr(test_raw$Long_Desc[large],1,55),
 Observed=y_test[large],Predicted=round(pred[large],1),Residual=round(residual[large],1))
write.csv(errors,file.path(results_dir,'largest_test_errors.csv'),row.names=FALSE)

# Coefficients from glmnet are returned in the original predictor units.
coefs <- do.call(rbind,lapply(seq_len(nrow(selected)),function(i) {
 n <- selected$Technique[i]; b <- as.matrix(coef(models[[n]],s=selected$Lambda[i]))
 data.frame(Technique=n,Term=rownames(b),Coefficient=b[,1],row.names=NULL)
}))
write.csv(coefs,file.path(results_dir,'all_final_coefficients.csv'),row.names=FALSE)
# Multiply raw coefficients by population SD for a comparable one-SD change.
scale_x <- sqrt(colMeans(sweep(x_dev,2,colMeans(x_dev),'-')^2))
b <- coefs[coefs$Technique==chosen_name & coefs$Term!='(Intercept)',]
b$Standardized <- b$Coefficient*scale_x[b$Term]
top <- b[head(order(abs(b$Standardized),decreasing=TRUE),10L),]
par(mar=c(4.2,12.5,1.3,1),las=1)
barplot(rev(top$Standardized),names.arg=rev(top$Term),horiz=TRUE,
 col=ifelse(rev(top$Standardized)>=0,blue,red),border=NA,
 xlab='Kcal per one predictor SD with other terms fixed',cex.names=.75)
abline(v=0,col='gray45')
write.csv(top,file.path(results_dir,'largest_standardized_coefficients.csv'),row.names=FALSE)

# Record versions, data identity and actual completion; no fabricated screen evidence.
record <- data.frame(Item=c('Status','Random seed','R version','glmnet version',
 'Matrix version','Source MD5','Paths fitted in cross validation','Settings compared'),
 Value=c('Completed all fits and held out evaluation',seed,R.version.string,
 as.character(getNamespaceVersion('glmnet')),as.character(getNamespaceVersion('Matrix')),
 unname(tools::md5sum(input)),55L,nrow(grid_results)))
tab(record)
write.csv(record,file.path(results_dir,'execution_record.csv'),row.names=FALSE)
writeLines(capture.output(sessionInfo()),file.path(results_dir,'sessionInfo.txt'))
jsonlite::write_json(list(seed=seed,development_n=nrow(dev_raw),test_n=nrow(test_raw),
 design_columns=ncol(x_dev),selected=selected,preferred=chosen_name,
 mean_cv_mse=mean_cv,test_metrics=test_metrics,largest_errors=errors),
 file.path(results_dir,'summary.json'),pretty=TRUE,auto_unbox=TRUE)
