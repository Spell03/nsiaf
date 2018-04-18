# Base de datos del sistema NSIAF

* Copiar el archivo de configuración

```sh
cp ../.env.ejemplo ../.env
```

* `Editar el archivo de acuerdo a la siguiente tabla de variables disponibles`

```sh
vim ../.env
```

* Crear un volumen para no perder la base de datos al momento de eliminar el contenedor

```sh
docker volume create almacenes_nsiaf-db
```

* Iniciar un contenedor del subsistema

```sh
docker run --name nsiaf-db --env-file ../.env -p 3306:3306 -v almacenes_nsiaf-db:/var/lib/mysql -d mysql:5.5
```
