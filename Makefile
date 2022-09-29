NAME = mathb
FQDN = $(NAME).in
MAIL = $(FQDN)@yahoo.com

help:
	@echo 'Usage: make [target]'
	@echo
	@echo 'Targets to run on live server:'
	@echo '  setup        Install Debian packages and Quicklisp for website.'
	@echo '  https        Reinstall live website and serve with Nginx via HTTPS.'
	@echo '  http         Reinstall live website and serve with Nginx via HTTP.'
	@echo '  rm           Uninstall live website.'
	@echo '  backup       Create live server data backup.'
	@echo '  follow-log   Follow logs on live server.'
	@echo '  follow-post  Follow POST logs on live server.'
	@echo
	@echo 'Low-level targets:'
	@echo '  live         Generate live website.'
	@echo '  site         Generate local website.'
	@echo
	@echo 'Development targets:'
	@echo '  data         Create a development data directory for testing.'
	@echo '  run          Run application.'
	@echo '  test         Test application code.'
	@echo '  pub          Publish updated website on live server.'
	@echo '  force-pub    Reset website on live server and publish website.'
	@echo '  pull-backup  Pull a backup of data from live server.'
	@echo
	@echo 'Default target:'
	@echo '  help        Show this help message.'


# Targets for Live Server
# -----------------------

setup:
	apt-get update
	apt-get -y install nginx certbot sbcl
	rm -rf /opt/quicklisp.lisp /opt/quicklisp
	curl https://beta.quicklisp.org/quicklisp.lisp -o /opt/quicklisp.lisp
	sbcl --load /opt/quicklisp.lisp \
	     --eval '(quicklisp-quickstart:install :path "/opt/quicklisp/")' \
	     --quit
	chown -R www-data:www-data /opt/quicklisp

https: http wait-http
	@echo Setting up HTTPS website ...
	certbot certonly -n --agree-tos -m '$(MAIL)' --webroot \
	                 -w '/opt/$(FQDN)/_live' -d '$(FQDN),www.$(FQDN)'
	(crontab -l | sed '/::::/d'; cat etc/crontab) | crontab
	ln -snf "$$PWD/etc/nginx/https.$(FQDN)" '/etc/nginx/sites-enabled/$(FQDN)'
	systemctl restart nginx
	@echo Done; echo

http: rm live mathb
	@echo Setting up HTTP website ...
	ln -snf "$$PWD/etc/nginx/http.$(FQDN)" '/etc/nginx/sites-enabled/$(FQDN)'
	systemctl restart nginx
	echo 127.0.0.1 '$(NAME)' >> /etc/hosts
	@echo Done; echo

wait-http:
	@echo Waiting for HTTP website to start ...
	while ! curl http://localhost:4242/; do sleep 1; echo Retrying ...; done
	@echo Done; echo

mathb:
	@echo Setting up mathb ...
	mkdir -p /opt/cache
	mkdir -p /opt/data/mathb
	chown -R www-data:www-data /opt/cache
	chown -R www-data:www-data /opt/data/mathb
	systemctl enable "/opt/mathb.in/etc/mathb.service"
	systemctl daemon-reload
	systemctl start mathb
	@echo Done; echo

rm: checkroot
	@echo Removing website ...
	rm -f '/etc/nginx/sites-enabled/$(FQDN)'
	systemctl restart nginx
	sed -i '/$(NAME)/d' /etc/hosts
	@echo
	@echo Removing mathb ...
	-systemctl stop mathb
	-systemctl disable mathb
	systemctl daemon-reload
	@echo
	@echo Following crontab entries left intact:
	crontab -l | grep -v "^#" || :
	@echo Done; echo

checkroot:
	@echo Checking if current user is root ...
	[ $$(id -u) = 0 ]
	@echo Done; echo

backup:
	tar -caf "/opt/cache/mathb-$$(date "+%Y-%m-%d_%H-%M-%S").tgz" -C /opt/data/ mathb/
	ls -1 /opt/cache/mathb-*.tgz | sort -r | tail -n +100 | xargs rm -vf
	ls -lh /opt/cache/
	df -h /

follow-log:
	sudo journalctl -fu mathb | grep -ivE "\.(css|js|png|ico|woff)|bot"

follow-post:
	sudo journalctl -fu mathb | grep -ivE "\.(css|js|png|ico|woff)|bot" | grep POST


# Low-Level Targets
# -----------------

live: site
	@echo Setting up live directory ...
	mv _live _gone || :
	mv _site _live
	rm -rf _gone
	@echo Done; echo

site:
	@echo Setting up site directory ...
	rm -rf _site/
	mkdir -p _site/css/ _site/js/
	cp -R web/css/* _site/css/
	cp -R web/js/* _site/js/
	cp -R web/img/* _site/
	git -C _site/js/ clone -b 1.2.0 --depth 1 https://github.com/susam/texme.git
	git -C _site/js/ clone -b v4.1.0 --depth 1 https://github.com/markedjs/marked.git
	git -C _site/js/ clone -b 3.2.2 --depth 1 https://github.com/mathjax/mathjax.git
	rm -rf _site/js/texme/.git
	rm -rf _site/js/marked/.git/
	rm -rf _site/js/mathjax/.git/
	@echo Done; echo


# Development Targets
# -------------------

data:
	sudo mkdir -p /opt/data/mathb/
	sudo cp -R meta/data/* /opt/data/mathb/
	sudo chown -R "$$USER" /opt/data/mathb/

run:
	sbcl --load mathb.lisp

test:
	sbcl --noinform --eval "(defvar *quit* t)" --load test.lisp

pub:
	git push
	ssh -t mathb.in "cd /opt/mathb.in/ && sudo git pull && sudo cp meta/data/post/0/0/*.txt /opt/data/mathb/post/0/0/ && sudo chown -R www-data:www-data meta/data/post/0/0/*.txt && sudo make live && sudo systemctl restart nginx mathb && sudo systemctl --no-pager status nginx mathb"

force-pub:
	git push -f
	ssh -t mathb.in "cd /opt/mathb.in/ && sudo git reset --hard HEAD~5 && sudo git pull && sudo cp meta/data/post/0/0/*.txt /opt/data/mathb/post/0/0/ && sudo chown -R www-data:www-data meta/data/post/0/0/*.txt && sudo make live && sudo systemctl restart nginx mathb && sudo systemctl --no-pager status nginx mathb"

pull-backup:
	mkdir -p ~/bkp/
	ssh mathb.in "tar -czf - -C /opt/data/ mathb/" > ~/bkp/mathb-$$(date "+%Y-%m-%d_%H-%M-%S").tgz
	ls -lh ~/bkp/
