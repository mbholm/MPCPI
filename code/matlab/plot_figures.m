% plot_figures.m -- draws every figure in the paper and the online appendix.
%
% Reads the coeffs_*.xlsx files written by the Stata stage (and data/mp_shocks.csv)
% and writes the figures to figures/ with the paper's numbering: figure1.eps,
% figure2a.eps, ..., figureB1.eps, ..., figureC1b.eps. Responses that are
% estimated but not shown in the paper go to figures/additional/. The mapping
% from figure file to coefficient file is listed in README.md.
%
% Run from any working directory: the script changes into output/ itself.
% Helper functions (ciplot, rgb, wprctile) live next to this file.

close all; clear; clc;
here = fileparts(mfilename('fullpath'));
addpath(here);
cd(fullfile(here, '..', '..', 'output'));   % coeffs_*.xlsx from the Stata stage live here
FIGDIR = fullfile(here, '..', '..', 'figures');          % paper figures are written here
if ~exist(FIGDIR, 'dir'), mkdir(FIGDIR); end
if ~exist(fullfile(FIGDIR, 'additional'), 'dir'), mkdir(fullfile(FIGDIR, 'additional')); end
fig = @(name) fullfile(FIGDIR, name);                    % full path of a figure file

%% ======================= PART 1: main-text figures, Figures B.1-B.2 =======================
% (confidence bands use the t distribution with N - k_lp - 1 degrees of freedom)
% housekeeping

% Run with the working directory set to replication/output/. This script reads
% ../data/mp_shocks.csv and the coeffs_*.xlsx in this folder, and writes the
% FIG_*.eps figures here.
assert(isfile('../data/mp_shocks.csv'), ...
    'Run plot_figures from replication/output/ after the Stata stage (mp_shocks.csv missing).');

% --- Figure sizing: pin a fixed, modest figure size so that when each EPS is
% scaled to its \includegraphics width in the paper, the axis ticks and labels
% stay legible. (The newer MATLAB default figure is large, which shrank the fonts
% after scaling.) The per-axis FontSize / label fontsize below are set to 22 for
% the same reason.
set(groot, 'defaultFigurePosition', [100 100 560 420]);


%% PLOT AGGREGATE IRF FIGURE

IRF_T       = 60;    % Size of IRFs
          
sign_outer  = 0.05; % Significance level for confidence bands
sign_inner  = 1/3;
k_lp        = 22;    % t-dist df adjustment (controls in the LP); see CONSISTENCY_REPORT.md C6
% shock = ''; % _market or blank (HPT)


%% MP SHOCK FIGURE

data = readmatrix("../data/mp_shocks.csv");
time = data(:,1) + (data(:,2)-1)./12;
mpshock = data(:,4);

figure()
plot(time,mpshock,'k-','Linewidth',1.5)
set(gca,'Box','on','FontSize',18)
ylabel('Percent','fontsize',18)
xlabel('Year','fontsize',18)
xticks(2000:2:2019)
grid()
xlim([2000 2019])
ylim([-1 1])
h = gcf;
print(h,'-depsc',fig('figure1'))
%print(h,'-dpdf','FIG_MPSHOCK')


%% INDIVIDUAL PRICE INDICES

for jj = 1:16

    zero_line = zeros(IRF_T+1,1);

    resmat = readmatrix(['coeffs_price_index_' num2str(jj) '.xlsx']);

    ci_lower_in     = resmat(:,1)-tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
    ci_upper_in     = resmat(:,1)+tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
    ci_lower_out    = resmat(:,1)-tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);
    ci_upper_out    = resmat(:,1)+tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);

    figure()
    hold on;
    plot(resmat(:,1),'b','Linewidth',2,'Color',rgb('Mediumblue')) 
    plot(ci_lower_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
    plot(ci_lower_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
    plot(ci_upper_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
    plot(ci_upper_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
    ciplot(ci_lower_in,ci_upper_in);
    ciplot(ci_lower_out,ci_upper_out);
    % plot(resmat(:,3),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
    % plot(resmat(:,4),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
    plot(zero_line,'black')
    hold off;
    % axis tight
    set(gca,'Box','on','FontSize',18)
xlim([1 IRF_T+1])
xticks(1:12:IRF_T+1)
xticklabels(0:12:IRF_T)
    % ylim([-6 6])
    ylabel('Percent','fontsize',18)
    xlabel('Month','fontsize',18)
    grid on
    % set(gca,'GridLineStyle','--')
    % ax = gca;
    % ax.GridAlpha = .5;

    h = gcf;
    % set(h,'PaperPositionMode','auto')
    % set(h,'PaperOrientation','landscape')
    % set(h,'Position',[0 0 1800 1200])
    % tightfig;
    % Figure 4, panels (a)-(l); the four categories not shown in the paper go to figures/additional/
    panel4 = containers.Map({9,3,4,2,11,13,16,5,14,15,1,8}, {'a','b','c','d','e','f','g','h','i','j','k','l'});
    if isKey(panel4, jj)
        print(h,'-depsc',fig(['figure4' panel4(jj)]))
    else
        print(h,'-depsc',fig(['additional/price_index_' num2str(jj)]))
    end
    % print(h,'-dpdf',['FIG_IRF_PRICE_INDEX_' num2str(jj)])

end


%% MEAN MEDIAN P25 P75 PRICE RESPONSE FIGURE

zero_line = zeros(IRF_T+1,1);
resmat = readmatrix('coeffs_price_index_detail.xlsx');
wmat = readmatrix('coeffs_price_index_detail_weights.xlsx');
wmat = wmat(1,:)'; % just keep one row
% normalize
wmat = wmat./sum(wmat);

meanR = sum(wmat'.*resmat,2);
medR = wprctile(resmat,50,wmat);
p25R = wprctile(resmat,25,wmat);
p75R = wprctile(resmat,75,wmat);


figure()
hold on;
plot(meanR,'b','Linewidth',2,'Color',rgb('Mediumblue')) 
plot(medR,'b--','Linewidth',2,'Color',rgb('Mediumblue')) 
plot(p25R,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(p75R,'b','Linewidth',1,'Color',rgb('Mediumblue'))
ciplot(p25R,p75R);
plot(zero_line,'black')
hold off;
set(gca,'Box','on','FontSize',18)
xlim([1 IRF_T+1])
xticks(1:12:IRF_T+1)
xticklabels(0:12:IRF_T)
ylabel('Percent','fontsize',18)
xlabel('Month','fontsize',18)
legend({'Mean','Median','25-75th percentile'},'Box','off','Location','Southwest','FontSize',14)
grid on

h = gcf;
print(h,'-depsc',fig('figure3'))


%% LOAD DATA

irf_policy_rate = readmatrix('coeffs_policy_rate_iv.xlsx');
irf_cpi = readmatrix('coeffs_kpijel.xlsx');
irf_cpi_JPE = readmatrix('coeffs_kpijel_JPE.xlsx');
irf_i44 = readmatrix('coeffs_i44.xlsx');
irf_usdnok = readmatrix('coeffs_usdnok.xlsx');
irf_cpi_weighted = readmatrix('coeffs_cpi_weighted.xlsx');
irf_dur_weighted = readmatrix('coeffs_dur_weighted.xlsx');
irf_nd_weighted = readmatrix('coeffs_nd_weighted.xlsx');
irf_ser_weighted = readmatrix('coeffs_ser_weighted.xlsx');
irf_ser_excl_housing_weighted = readmatrix('coeffs_ser_excl_housing_weighted.xlsx');
irf_int_imp_weighted = readmatrix('coeffs_int_import_share.xlsx');
irf_int_deb_weighted = readmatrix('coeffs_int_deb_costs.xlsx');
irf_int_nwc_weighted = readmatrix('coeffs_int_nwc.xlsx');
irf_int_wage_share_weighted = readmatrix('coeffs_int_wage_share.xlsx');
irf_lph = readmatrix('coeffs_logwageph.xlsx');
irf_lpe = readmatrix('coeffs_logwagepe.xlsx');
irf_wage = readmatrix('coeffs_logwagetot.xlsx');
irf_hours = readmatrix('coeffs_loghours.xlsx');
irf_empl = readmatrix('coeffs_logemployment.xlsx');



%% POLICY RATE AGGREGATE



zero_line = zeros(IRF_T+1,1);

resmat = irf_policy_rate;

ci_lower_in     = resmat(:,1)-tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_in     = resmat(:,1)+tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_lower_out    = resmat(:,1)-tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_out    = resmat(:,1)+tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);

figure()
hold on;
plot(resmat(:,1),'b','Linewidth',2,'Color',rgb('Mediumblue')) 
plot(ci_lower_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_lower_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
ciplot(ci_lower_in,ci_upper_in);
ciplot(ci_lower_out,ci_upper_out);
% plot(resmat(:,3),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
% plot(resmat(:,4),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
plot(zero_line,'black')
hold off;
% axis tight
set(gca,'Box','on','FontSize',18)
xlim([1 IRF_T+1])
xticks(1:12:IRF_T+1)
xticklabels(0:12:IRF_T)
% ylim([-8 6])
ylabel('Percent','fontsize',18)
xlabel('Month','fontsize',18)
grid on
% set(gca,'GridLineStyle','--')
% ax = gca;
% ax.GridAlpha = .5;

h = gcf;
% set(h,'PaperPositionMode','auto')
% set(h,'PaperOrientation','landscape')
% set(h,'Position',[0 0 1800 1200])
% tightfig;
print(h,'-depsc',fig('figureB1'))
%print(h,'-dpdf',['FIG_IRF_CPI_AGG' shock])

%% CPI-AEL AGGREGATE



zero_line = zeros(IRF_T+1,1);

resmat = irf_cpi;

ci_lower_in     = resmat(:,1)-tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_in     = resmat(:,1)+tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_lower_out    = resmat(:,1)-tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_out    = resmat(:,1)+tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);

figure()
hold on;
plot(resmat(:,1),'b','Linewidth',2,'Color',rgb('Mediumblue')) 
plot(ci_lower_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_lower_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
ciplot(ci_lower_in,ci_upper_in);
ciplot(ci_lower_out,ci_upper_out);
% plot(resmat(:,3),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
% plot(resmat(:,4),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
plot(zero_line,'black')
hold off;
% axis tight
set(gca,'Box','on','FontSize',18)
xlim([1 IRF_T+1])
xticks(1:12:IRF_T+1)
xticklabels(0:12:IRF_T)
% ylim([-8 6])
ylabel('Percent','fontsize',18)
xlabel('Month','fontsize',18)
grid on
% set(gca,'GridLineStyle','--')
% ax = gca;
% ax.GridAlpha = .5;

h = gcf;
% set(h,'PaperPositionMode','auto')
% set(h,'PaperOrientation','landscape')
% set(h,'Position',[0 0 1800 1200])
% tightfig;
print(h,'-depsc',fig('figure2a'))
%print(h,'-dpdf',['FIG_IRF_CPI_AGG' shock])

%% CPI-AEL AGGREGATE - JPE SETUP



zero_line = zeros(IRF_T+1,1);

resmat = irf_cpi_JPE;

ci_lower_in     = resmat(:,1)-tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_in     = resmat(:,1)+tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_lower_out    = resmat(:,1)-tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_out    = resmat(:,1)+tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);

figure()
hold on;
plot(resmat(:,1),'b','Linewidth',2,'Color',rgb('Mediumblue')) 
plot(ci_lower_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_lower_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
ciplot(ci_lower_in,ci_upper_in);
ciplot(ci_lower_out,ci_upper_out);
% plot(resmat(:,3),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
% plot(resmat(:,4),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
plot(zero_line,'black')
hold off;
% axis tight
set(gca,'Box','on','FontSize',18)
xlim([1 IRF_T+1])
xticks(1:12:IRF_T+1)
xticklabels(0:12:IRF_T)
% ylim([-8 6])
ylabel('Percent','fontsize',18)
xlabel('Month','fontsize',18)
grid on
% set(gca,'GridLineStyle','--')
% ax = gca;
% ax.GridAlpha = .5;

h = gcf;
% set(h,'PaperPositionMode','auto')
% set(h,'PaperOrientation','landscape')
% set(h,'Position',[0 0 1800 1200])
% tightfig;
print(h,'-depsc',fig('figureB2'))
%print(h,'-dpdf',['FIG_IRF_CPI_AGG' shock])

%% USDNOK AGGREGATE



zero_line = zeros(IRF_T+1,1);

resmat = irf_usdnok;

ci_lower_in     = resmat(:,1)-tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_in     = resmat(:,1)+tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_lower_out    = resmat(:,1)-tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_out    = resmat(:,1)+tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);

figure()
hold on;
plot(resmat(:,1),'b','Linewidth',2,'Color',rgb('Mediumblue')) 
plot(ci_lower_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_lower_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
ciplot(ci_lower_in,ci_upper_in);
ciplot(ci_lower_out,ci_upper_out);
% plot(resmat(:,3),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
% plot(resmat(:,4),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
plot(zero_line,'black')
hold off;
% axis tight
set(gca,'Box','on','FontSize',18)
xlim([1 IRF_T+1])
xticks(1:12:IRF_T+1)
xticklabels(0:12:IRF_T)
% ylim([-6 6])
ylabel('Percent','fontsize',18)
xlabel('Month','fontsize',18)
grid on
% set(gca,'GridLineStyle','--')
% ax = gca;
% ax.GridAlpha = .5;

h = gcf;
% set(h,'PaperPositionMode','auto')
% set(h,'PaperOrientation','landscape')
% set(h,'Position',[0 0 1800 1200])
% tightfig;
print(h,'-depsc',fig('additional/usdnok_response'))
%print(h,'-dpdf',['FIG_IRF_USDNOK_AGG' shock])

%% I44 AGGREGATE



zero_line = zeros(IRF_T+1,1);

resmat = irf_i44;

ci_lower_in     = resmat(:,1)-tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_in     = resmat(:,1)+tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_lower_out    = resmat(:,1)-tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_out    = resmat(:,1)+tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);

figure()
hold on;
plot(resmat(:,1),'b','Linewidth',2,'Color',rgb('Mediumblue')) 
plot(ci_lower_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_lower_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
ciplot(ci_lower_in,ci_upper_in);
ciplot(ci_lower_out,ci_upper_out);
% plot(resmat(:,3),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
% plot(resmat(:,4),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
plot(zero_line,'black')
hold off;
% axis tight
set(gca,'Box','on','FontSize',18)
xlim([1 IRF_T+1])
xticks(1:12:IRF_T+1)
xticklabels(0:12:IRF_T)
% ylim([-6 6])
ylabel('Percent','fontsize',18)
xlabel('Month','fontsize',18)
grid on
% set(gca,'GridLineStyle','--')
% ax = gca;
% ax.GridAlpha = .5;

h = gcf;
% set(h,'PaperPositionMode','auto')
% set(h,'PaperOrientation','landscape')
% set(h,'Position',[0 0 1800 1200])
% tightfig;
print(h,'-depsc',fig('figure8a'))
%print(h,'-dpdf',['FIG_IRF_I44_AGG' shock])

%% PLOT FIGURE: IRF_AGGREGATE


zero_line = zeros(IRF_T+1,1);

resmat = irf_cpi_weighted;

ci_lower_in     = resmat(:,1)-tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_in     = resmat(:,1)+tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_lower_out    = resmat(:,1)-tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_out    = resmat(:,1)+tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);

figure()
hold on;
plot(resmat(:,1),'b','Linewidth',2,'Color',rgb('Mediumblue')) 
plot(ci_lower_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_lower_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
ciplot(ci_lower_in,ci_upper_in);
ciplot(ci_lower_out,ci_upper_out);
% plot(resmat(:,3),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
% plot(resmat(:,4),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
plot(zero_line,'black')
hold off;
% axis tight
set(gca,'Box','on','FontSize',18)
xlim([1 IRF_T+1])
xticks(1:12:IRF_T+1)
xticklabels(0:12:IRF_T)
ylim([-5 2])
ylabel('Percent','fontsize',18)
xlabel('Month','fontsize',18)
grid on
% set(gca,'GridLineStyle','--')
% ax = gca;
% ax.GridAlpha = .5;

h = gcf;
% set(h,'PaperPositionMode','auto')
% set(h,'PaperOrientation','landscape')
% set(h,'Position',[0 0 1800 1200])
% tightfig;
print(h,'-depsc',fig('figure2b'))
%print(h,'-dpdf',['FIG_IRF_AGG_WEIGHTED' shock])

%% PLOT FIGURE: IRF DURABLES

zero_line = zeros(IRF_T+1,1);

resmat = irf_dur_weighted;

ci_lower_in     = resmat(:,1)-tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_in     = resmat(:,1)+tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_lower_out    = resmat(:,1)-tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_out    = resmat(:,1)+tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);

figure()
hold on;
plot(resmat(:,1),'b','Linewidth',2,'Color',rgb('Mediumblue')) 
plot(ci_lower_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_lower_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
ciplot(ci_lower_in,ci_upper_in);
ciplot(ci_lower_out,ci_upper_out);
% plot(resmat(:,3),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
% plot(resmat(:,4),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
plot(zero_line,'black')
hold off;
% axis tight
set(gca,'Box','on','FontSize',18)
xlim([1 IRF_T+1])
xticks(1:12:IRF_T+1)
xticklabels(0:12:IRF_T)
% ylim([-20 10])
ylabel('Percent','fontsize',18)
xlabel('Month','fontsize',18) 
grid on
% set(gca,'GridLineStyle','--')
% ax = gca;
% ax.GridAlpha = .5;

h = gcf;
% set(h,'PaperPositionMode','auto')
% set(h,'PaperOrientation','landscape')
% set(h,'Position',[0 0 1800 1200])
% tightfig;
print(h,'-depsc',fig('figure6a'))
%print(h,'-dpdf',['FIG_IRF_AGG_DUR_WEIGHTED' shock])

%% PLOT FIGURE: IRF NON DURABLES


zero_line = zeros(IRF_T+1,1);

resmat = irf_nd_weighted;

ci_lower_in     = resmat(:,1)-tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_in     = resmat(:,1)+tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_lower_out    = resmat(:,1)-tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_out    = resmat(:,1)+tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);

figure()
hold on;
plot(resmat(:,1),'b','Linewidth',2,'Color',rgb('Mediumblue')) 
plot(ci_lower_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_lower_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
ciplot(ci_lower_in,ci_upper_in);
ciplot(ci_lower_out,ci_upper_out);
% plot(resmat(:,3),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
% plot(resmat(:,4),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
plot(zero_line,'black')
hold off;
% axis tight
set(gca,'Box','on','FontSize',18)
xlim([1 IRF_T+1])
xticks(1:12:IRF_T+1)
xticklabels(0:12:IRF_T)
% ylim([-10 10])
ylabel('Percent','fontsize',18)
xlabel('Month','fontsize',18)
grid on
% set(gca,'GridLineStyle','--')
% ax = gca;
% ax.GridAlpha = .5;

h = gcf;
% set(h,'PaperPositionMode','auto')
% set(h,'PaperOrientation','landscape')
% set(h,'Position',[0 0 1800 1200])
% tightfig;
print(h,'-depsc',fig('figure6b'))
%print(h,'-dpdf',['FIG_IRF_AGG_ND_WEIGHTED' shock])

%% PLOT FIGURE: IRF SERVICES


zero_line = zeros(IRF_T+1,1);

resmat = irf_ser_weighted;

ci_lower_in     = resmat(:,1)-tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_in     = resmat(:,1)+tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_lower_out    = resmat(:,1)-tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_out    = resmat(:,1)+tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);

figure()
hold on;
plot(resmat(:,1),'b','Linewidth',2,'Color',rgb('Mediumblue')) 
plot(ci_lower_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_lower_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
ciplot(ci_lower_in,ci_upper_in);
ciplot(ci_lower_out,ci_upper_out);
% plot(resmat(:,3),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
% plot(resmat(:,4),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
plot(zero_line,'black')
hold off;
% axis tight
set(gca,'Box','on','FontSize',18)
xlim([1 IRF_T+1])
xticks(1:12:IRF_T+1)
xticklabels(0:12:IRF_T)
% ylim([-6 6])
ylabel('Percent','fontsize',18)
xlabel('Month','fontsize',18)
grid on
% set(gca,'GridLineStyle','--')
% ax = gca;
% ax.GridAlpha = .5;

h = gcf;
% set(h,'PaperPositionMode','auto')
% set(h,'PaperOrientation','landscape')
% set(h,'Position',[0 0 1800 1200])
% tightfig;
print(h,'-depsc',fig('figure6c'))
%print(h,'-dpdf',['FIG_IRF_AGG_SER_WEIGHTED' shock])



%% PLOT FIGURE: IRF SERVICES


zero_line = zeros(IRF_T+1,1);

resmat = irf_ser_excl_housing_weighted;

ci_lower_in     = resmat(:,1)-tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_in     = resmat(:,1)+tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_lower_out    = resmat(:,1)-tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_out    = resmat(:,1)+tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);

figure()
hold on;
plot(resmat(:,1),'b','Linewidth',2,'Color',rgb('Mediumblue')) 
plot(ci_lower_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_lower_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
ciplot(ci_lower_in,ci_upper_in);
ciplot(ci_lower_out,ci_upper_out);
% plot(resmat(:,3),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
% plot(resmat(:,4),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
plot(zero_line,'black')
hold off;
% axis tight
set(gca,'Box','on','FontSize',18)
xlim([1 IRF_T+1])
xticks(1:12:IRF_T+1)
xticklabels(0:12:IRF_T)
% ylim([-6 6])
ylabel('Percent','fontsize',18)
xlabel('Month','fontsize',18)
grid on
% set(gca,'GridLineStyle','--')
% ax = gca;
% ax.GridAlpha = .5;

h = gcf;
% set(h,'PaperPositionMode','auto')
% set(h,'PaperOrientation','landscape')
% set(h,'Position',[0 0 1800 1200])
% tightfig;
print(h,'-depsc',fig('figure6d'))
%print(h,'-dpdf',['FIG_IRF_AGG_SER_WEIGHTED' shock])


%% PLOT FIGURE: IRF_INTERACTED IMPORT SHARE


zero_line = zeros(IRF_T+1,1);

resmat = irf_int_imp_weighted;

ci_lower_in     = resmat(:,1)-tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_in     = resmat(:,1)+tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_lower_out    = resmat(:,1)-tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_out    = resmat(:,1)+tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);

figure()
hold on;
plot(resmat(:,1),'b','Linewidth',2,'Color',rgb('Mediumblue')) 
plot(ci_lower_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_lower_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
ciplot(ci_lower_in,ci_upper_in);
ciplot(ci_lower_out,ci_upper_out);
% plot(resmat(:,3),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
% plot(resmat(:,4),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
plot(zero_line,'black')
hold off;
% axis tight
set(gca,'Box','on','FontSize',18)
xlim([1 IRF_T+1])
xticks(1:12:IRF_T+1)
xticklabels(0:12:IRF_T)
% ylim([-15 10])
ylabel('Percent','fontsize',18)
xlabel('Month','fontsize',18) 
grid on
% set(gca,'GridLineStyle','--')
% ax = gca;
% ax.GridAlpha = .5;

h = gcf;
% set(h,'PaperPositionMode','auto')
% set(h,'PaperOrientation','landscape')
% set(h,'Position',[0 0 1800 1200])
% tightfig;
print(h,'-depsc',fig('figure8b'))
%print(h,'-dpdf',['FIG_IRF_INT_IMP_WEIGHTED' shock])


%% PLOT FIGURE: IRF_INTERACTED CONSUMPTION EXPOSURE


zero_line = zeros(IRF_T+1,1);

resmat = irf_int_deb_weighted;

ci_lower_in     = resmat(:,1)-tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_in     = resmat(:,1)+tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_lower_out    = resmat(:,1)-tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_out    = resmat(:,1)+tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);

figure()
hold on;
plot(resmat(:,1),'b','Linewidth',2,'Color',rgb('Mediumblue')) 
plot(ci_lower_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_lower_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
ciplot(ci_lower_in,ci_upper_in);
ciplot(ci_lower_out,ci_upper_out);
% plot(resmat(:,3),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
% plot(resmat(:,4),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
plot(zero_line,'black')
hold off;
% axis tight
set(gca,'Box','on','FontSize',18)
xlim([1 IRF_T+1])
xticks(1:12:IRF_T+1)
xticklabels(0:12:IRF_T)
% ylim([-0.5 1])
ylabel('Percent','fontsize',18)
xlabel('Month','fontsize',18)
grid on
% set(gca,'GridLineStyle','--')
% ax = gca;
% ax.GridAlpha = .5;

h = gcf;
% set(h,'PaperPositionMode','auto')
% set(h,'PaperOrientation','landscape')
% set(h,'Position',[0 0 1800 1200])
% tightfig;
print(h,'-depsc',fig('figure5a'))
%print(h,'-dpdf',['FIG_IRF_INT_DEB_WEIGHTED' shock])


%% PLOT FIGURE: IRF_INTERACTED Net working capital SHARE


zero_line = zeros(IRF_T+1,1);

resmat = irf_int_nwc_weighted;

ci_lower_in     = resmat(:,1)-tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_in     = resmat(:,1)+tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_lower_out    = resmat(:,1)-tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_out    = resmat(:,1)+tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);

figure()
hold on;
plot(resmat(:,1),'b','Linewidth',2,'Color',rgb('Mediumblue')) 
plot(ci_lower_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_lower_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
ciplot(ci_lower_in,ci_upper_in);
ciplot(ci_lower_out,ci_upper_out);
% plot(resmat(:,3),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
% plot(resmat(:,4),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
plot(zero_line,'black')
hold off;
% axis tight
set(gca,'Box','on','FontSize',18)
xlim([1 IRF_T+1])
xticks(1:12:IRF_T+1)
xticklabels(0:12:IRF_T)
% ylim([-0.5 1])
ylabel('Percent','fontsize',18)
xlabel('Month','fontsize',18)
grid on
% set(gca,'GridLineStyle','--')
% ax = gca;
% ax.GridAlpha = .5;

h = gcf;
% set(h,'PaperPositionMode','auto')
% set(h,'PaperOrientation','landscape')
% set(h,'Position',[0 0 1800 1200])
% tightfig;
print(h,'-depsc',fig('figure5b'))
%print(h,'-dpdf',['FIG_IRF_INT_CCS_WEIGHTED' shock])


%% PLOT FIGURE: IRF_INTERACTED WAGE SHARE OF COSTS


zero_line = zeros(IRF_T+1,1);

resmat = irf_int_wage_share_weighted;

ci_lower_in     = resmat(:,1)-tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_in     = resmat(:,1)+tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_lower_out    = resmat(:,1)-tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_out    = resmat(:,1)+tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);

figure()
hold on;
plot(resmat(:,1),'b','Linewidth',2,'Color',rgb('Mediumblue'))
plot(ci_lower_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_lower_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
ciplot(ci_lower_in,ci_upper_in);
ciplot(ci_lower_out,ci_upper_out);
plot(zero_line,'black')
hold off;
set(gca,'Box','on','FontSize',18)
xlim([1 IRF_T+1])
xticks(1:12:IRF_T+1)
xticklabels(0:12:IRF_T)
ylabel('Percent','fontsize',18)
xlabel('Month','fontsize',18)
grid on

h = gcf;
print(h,'-depsc',fig('additional/interaction_wage_share'))


%% PLOT FIGURE: WAGE

qlength = 20;

zero_line = zeros(qlength+1,1);

resmat = irf_lpe;

ci_lower_in     = resmat(:,1)-tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_in     = resmat(:,1)+tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_lower_out    = resmat(:,1)-tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_out    = resmat(:,1)+tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);

figure()
hold on;
plot(resmat(:,1),'b','Linewidth',2,'Color',rgb('Mediumblue')) 
plot(ci_lower_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_lower_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
ciplot(ci_lower_in,ci_upper_in);
ciplot(ci_lower_out,ci_upper_out);
% plot(resmat(:,3),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
% plot(resmat(:,4),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
plot(zero_line,'black')
hold off;
% axis tight
set(gca,'Box','on','FontSize',18)
xlim([1 qlength+1])
xticks(1:4:qlength+1)
xticklabels(0:4:qlength)
% ylim([-0.5 1])
ylabel('Percent','fontsize',18)
xlabel('Quarter','fontsize',18)
grid on
% set(gca,'GridLineStyle','--')
% ax = gca;
% ax.GridAlpha = .5;

h = gcf;
% set(h,'PaperPositionMode','auto')
% set(h,'PaperOrientation','landscape')
% set(h,'Position',[0 0 1800 1200])
% tightfig;
print(h,'-depsc',fig('additional/wage_per_employee'))
%print(h,'-dpdf',['FIG_IRF_INT_CCS_WEIGHTED' shock])



%% PLOT FIGURE: WAGE

qlength = 20;

zero_line = zeros(qlength+1,1);

resmat = irf_lph;

ci_lower_in     = resmat(:,1)-tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_in     = resmat(:,1)+tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_lower_out    = resmat(:,1)-tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_out    = resmat(:,1)+tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);

figure()
hold on;
plot(resmat(:,1),'b','Linewidth',2,'Color',rgb('Mediumblue')) 
plot(ci_lower_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_lower_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
ciplot(ci_lower_in,ci_upper_in);
ciplot(ci_lower_out,ci_upper_out);
% plot(resmat(:,3),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
% plot(resmat(:,4),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
plot(zero_line,'black')
hold off;
% axis tight
set(gca,'Box','on','FontSize',18)
xlim([1 qlength+1])
xticks(1:4:qlength+1)
xticklabels(0:4:qlength)
% ylim([-0.5 1])
ylabel('Percent','fontsize',18)
xlabel('Quarter','fontsize',18)
grid on
% set(gca,'GridLineStyle','--')
% ax = gca;
% ax.GridAlpha = .5;

h = gcf;
% set(h,'PaperPositionMode','auto')
% set(h,'PaperOrientation','landscape')
% set(h,'Position',[0 0 1800 1200])
% tightfig;
print(h,'-depsc',fig('figure7c'))
%print(h,'-dpdf',['FIG_IRF_INT_CCS_WEIGHTED' shock])



%% PLOT FIGURE: WAGE

qlength = 20;

zero_line = zeros(qlength+1,1);

resmat = irf_wage;

ci_lower_in     = resmat(:,1)-tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_in     = resmat(:,1)+tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_lower_out    = resmat(:,1)-tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_out    = resmat(:,1)+tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);

figure()
hold on;
plot(resmat(:,1),'b','Linewidth',2,'Color',rgb('Mediumblue')) 
plot(ci_lower_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_lower_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
ciplot(ci_lower_in,ci_upper_in);
ciplot(ci_lower_out,ci_upper_out);
% plot(resmat(:,3),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
% plot(resmat(:,4),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
plot(zero_line,'black')
hold off;
% axis tight
set(gca,'Box','on','FontSize',18)
xlim([1 qlength+1])
xticks(1:4:qlength+1)
xticklabels(0:4:qlength)
% ylim([-0.5 1])
ylabel('Percent','fontsize',18)
xlabel('Quarter','fontsize',18)
grid on
% set(gca,'GridLineStyle','--')
% ax = gca;
% ax.GridAlpha = .5;

h = gcf;
% set(h,'PaperPositionMode','auto')
% set(h,'PaperOrientation','landscape')
% set(h,'Position',[0 0 1800 1200])
% tightfig;
print(h,'-depsc',fig('figure7a'))
%print(h,'-dpdf',['FIG_IRF_INT_CCS_WEIGHTED' shock])



%% PLOT FIGURE: hours

qlength = 20;

zero_line = zeros(qlength+1,1);

resmat = irf_hours;

ci_lower_in     = resmat(:,1)-tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_in     = resmat(:,1)+tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_lower_out    = resmat(:,1)-tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_out    = resmat(:,1)+tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);

figure()
hold on;
plot(resmat(:,1),'b','Linewidth',2,'Color',rgb('Mediumblue')) 
plot(ci_lower_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_lower_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
ciplot(ci_lower_in,ci_upper_in);
ciplot(ci_lower_out,ci_upper_out);
% plot(resmat(:,3),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
% plot(resmat(:,4),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
plot(zero_line,'black')
hold off;
% axis tight
set(gca,'Box','on','FontSize',18)
xlim([1 qlength+1])
xticks(1:4:qlength+1)
xticklabels(0:4:qlength)
% ylim([-0.5 1])
ylabel('Percent','fontsize',18)
xlabel('Quarter','fontsize',18)
grid on
% set(gca,'GridLineStyle','--')
% ax = gca;
% ax.GridAlpha = .5;

h = gcf;
% set(h,'PaperPositionMode','auto')
% set(h,'PaperOrientation','landscape')
% set(h,'Position',[0 0 1800 1200])
% tightfig;
print(h,'-depsc',fig('figure7b'))
%print(h,'-dpdf',['FIG_IRF_INT_CCS_WEIGHTED' shock])


%% PLOT FIGURE: employment

qlength = 20;

zero_line = zeros(qlength+1,1);

resmat = irf_empl;

ci_lower_in     = resmat(:,1)-tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_in     = resmat(:,1)+tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_lower_out    = resmat(:,1)-tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);
ci_upper_out    = resmat(:,1)+tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);

figure()
hold on;
plot(resmat(:,1),'b','Linewidth',2,'Color',rgb('Mediumblue')) 
plot(ci_lower_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_lower_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
plot(ci_upper_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
ciplot(ci_lower_in,ci_upper_in);
ciplot(ci_lower_out,ci_upper_out);
% plot(resmat(:,3),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
% plot(resmat(:,4),'Linestyle','-','Linewidth',2,'Color',rgb('DarkRed'))
plot(zero_line,'black')
hold off;
% axis tight
set(gca,'Box','on','FontSize',18)
xlim([1 qlength+1])
xticks(1:4:qlength+1)
xticklabels(0:4:qlength)
% ylim([-0.5 1])
ylabel('Percent','fontsize',18)
xlabel('Quarter','fontsize',18)
grid on
% set(gca,'GridLineStyle','--')
% ax = gca;
% ax.GridAlpha = .5;

h = gcf;
% set(h,'PaperPositionMode','auto')
% set(h,'PaperOrientation','landscape')
% set(h,'Position',[0 0 1800 1200])
% tightfig;
print(h,'-depsc',fig('additional/employment'))
%print(h,'-dpdf',['FIG_IRF_INT_CCS_WEIGHTED' shock])


%% ======================= PART 2: Figures B.3, B.4 and C.1 =======================
% Same styling and confidence-band construction as Part 1.
IRF_T = 60; sign_outer = 0.05; sign_inner = 1/3; k_lp = 22;
zero_line = zeros(IRF_T+1,1);

specs = { ...
    'coeffs_cpi_weighted_incl_govreg_excl_elec', 'figureB3a'; ...
    'coeffs_cpi_weighted_incl_govreg',           'figureB3b'; ...
    'coeffs_placebo_govreg_weighted',            'figureB4a'; ...
    'coeffs_int_int_cost',                       'figureC1a'; ...
    'coeffs_int_icr',                            'figureC1b'; ...
    'coeffs_int_inv_icr',                        'additional/interaction_inverse_coverage_ratio'; ...
    };
% individual placebo series (one file per regulated index; see placebo_govreg_ids.txt)
% individual placebo series = Figure B.4, panels (b)-(f); output/placebo_govreg_ids.txt maps id -> index
panelB4 = {'b','c','d','e','f'};
for ii = 1:5
    specs(end+1,:) = {['coeffs_placebo_govreg_' num2str(ii)], ['figureB4' panelB4{ii}]}; %#ok<SAGROW>
end

for s = 1:size(specs,1)
    resmat = readmatrix([specs{s,1} '.xlsx']);
    ci_lower_in  = resmat(:,1)-tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
    ci_upper_in  = resmat(:,1)+tinv(1-sign_inner/2,resmat(:,3)-k_lp-1).*resmat(:,2);
    ci_lower_out = resmat(:,1)-tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);
    ci_upper_out = resmat(:,1)+tinv(1-sign_outer/2,resmat(:,3)-k_lp-1).*resmat(:,2);
    figure()
    hold on;
    plot(resmat(:,1),'b','Linewidth',2,'Color',rgb('Mediumblue'))
    plot(ci_lower_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
    plot(ci_lower_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
    plot(ci_upper_in,'b','Linewidth',1,'Color',rgb('Mediumblue'))
    plot(ci_upper_out,'b','Linewidth',1,'Color',rgb('Mediumblue'))
    ciplot(ci_lower_in,ci_upper_in);
    ciplot(ci_lower_out,ci_upper_out);
    plot(zero_line,'black')
    hold off;
    set(gca,'Box','on','FontSize',18)
    xlim([1 IRF_T+1]); xticks(1:12:IRF_T+1); xticklabels(0:12:IRF_T)
    ylabel('Percent','fontsize',18); xlabel('Month','fontsize',18)
    grid on
    h = gcf;
    print(h,'-depsc',fig(specs{s,2}))
end
disp(['plot_figures: figures written to ' FIGDIR])
