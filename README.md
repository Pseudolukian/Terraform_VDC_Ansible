# Ansible: развёртывание Django на 3 VPS

Это короткий мануал по развёртыванию Django-стека на 3 виртуальных машинах, созданных с помощью Terraform в VMware Cloud Director. Для запуска проекта понадобятся: Go, Terraform, провайдер VDC, Python3 и Ansible. Все действия в инструкции приведены для Ubuntu 18-20.

Если у вас не установлен Go, Terraform или провайдер VCD. Инструкции по их установки есть тут. 


## Как работает проект

Terraform через VCD по API дёргает Cloud Director и разворачивает в нём 3 VM связанные маршрутизируемой сетью. Затем с помощью Ansible на серверах разворачивается ПО: Nginx, Django, Gunicorn,PostgreSQL.

Все настройки Terraform лежат в файле settings.tf, а основной файл конфигурации — main.tf. Настройка для подключения находятся в блоке «Настройки для подключения» файла settings.tf. 

Вот пример соотношения настроек в файле settings.tf с WEB GUI VMware CLoud Director на примере Виртуального ЦОДа от 1cloud:

![1cloud VDC](https://1cloudstat.com/img/blog/651.png)

После заполнения всех переменных, можно запускать terraform командой terraform apply. Пойдёт выполнение разворачивания инфраструктуры. 

Вот как происходит создание инфраструктуры по шагам:
1. Создаётся маршрутизируемая сеть 10.10.0.1/24;
2. Задаются 2 DNS-сервера: 8.8.8.8 и 1.1.1.1;
3. Сеть подключается к эджу;
4. Настраиваются SNAT- и DNAT-правила;
5. Создаются 3 VM с Ubuntu 18;
6. Сервера подключаются к сети;
7. Админу устанавливается новый пароль;
8. Машины запускаются через force customization.


### Сетевые настройки эджа

На эдже устанавливаются следующие 4 DNAT-правила: 1) 89.22.173.56:22 → 10.10.0.3:22 — Nginx; 2) 89.22.173.56:80 → 10.10.0.3:80 — Nginx; 3) 89.22.173.56:23 → 10.10.0.4:22 — Django; 4) 89.22.173.56:24 → 10.10.0.5:22 — PostgreSQL. Также есть 1 SNAT-правило: 10.10.0.1/24:any → 89.22.173.56:any.

DNAT-правила нужны для подключения Ansible по SHH и HTTP на 80 порту, а SNAT — обеспечивает коммуникацию с миром по всем портам. 

Мы явно задали 2 DNS-сервера для избегания проблем с DNS. В ряде случаев у нас может не быть прав на доступ к DNS-настройкам на эдже, поэтому мы задаём их на уровне сети. 

Время создания инфраструктура — 1,5-2 минуты, после можно запускать Ansible, который установит всё ПО.


### Работа с Ansible

Ansible использует 3 роли: frontend, backend и posgresql. Все настройки для ролей и инвентаризационного файла лежат в group_vars/all.yaml. Мастер плейбук — side.yaml. Запускается он так: ansible-playbook -i hosts.ini side.yaml. 

Последовательность выполнения ролей и задач такова: 
1. Роль frontend: 1) Обновление apt-пакетов; 2) Установка Nginx и копирование конфига на сервер; 3) Перезапуск Nginx.
2. Роль postgresql: 1) Обновление apt, установка и запуск PostgreSQL; 2) Создание БД и пользователя; 3) Открытие всех портов для прослушивания; 4) Добавление IP-адрес Django в разрешённые; 5) Перезапуск PostgreSQL.
3. Роль backend: 1) Установка пакетов для Django и создание рабочей директории проекта; 2) Установка Django и psycopg2; 3) Создание демо-проекта и Web-приложения; 3) Копирование Django-конфига

    Миграция изменений; 4) Установка Gunicorn; 5) Копирование Gunicorn-конфига; 6) Копирование скрипта запуска Gunicorn; 6) Создание пользователя www; 7) Копирование Gunicorn юнита; 8) Обновление юнитов; 9) Запуск Gunicorn при старте или перезагрузке; 10) Запуск Gunicorn.


При повторном запуске плейбука на этапе создание демо-проекта будет выпадать ошибка (пока), так как такой проект уже существует — это нормально. Можно применить команду ansible-playbook -i hosts.ini side.yaml --start-at-task="Создание первого Web-приложения"


## Что предстоит ещё реализовать

Проект полностью рабочий, однако можно лучше. Вот что хотелось бы ещё сделать:
* Рефакторинг кода и уход от shell и команд;
* Добавить Django-пользователя;
* Вставка кондишенов;
* Единый источник данный для Terraform и Ansible;
* Автоматическая сборка Inventary-файла;
* Полностью автоматический deploy-всего проекта.