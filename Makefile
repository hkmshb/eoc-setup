help:
	@echo "Helper script for EOC development related tasks"
	@echo "Please use \`make <target>' where <target> is one of"
	@echo "  clean           to remove project docker volumes"
	@echo "  purge           to remove all clone project repos"
	@echo "  init            to pull all fetch project repos and build docker images"
	@echo "  test            to run unit & integration tests"


clean:
	rm -rf ./.data/*

purge:
	./src/bin/manage.sh purge

init:
	./src/bin/manage.sh init

up-core:
	source .env.local && docker-compose -p eoc-orig up db redis solr

up-ckan:
	source .env.local && docker-compose -p eoc-orig up datapusher ckan

test:
	pycodestyle --count --ignore=E501,E731 ./src/extensions/ckanext-eoc/ckanext/eoc
