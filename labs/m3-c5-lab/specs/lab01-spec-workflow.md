Necesito construir un workflow de despliegue en gh actions:
- debera tener un dispatch manual (trigger)
- va a utilizar variables y secretos cargados en environment lab
- podes utilizar como referencia el archivo m3-c4-infra-ci.yml
- su funcion sera manejar el deploy/destroy de recursos en aws.
- necesito un job de output que me de la ip de las ec2 creadas.
- no vas a crear o alterar los files de .tf
- no vas a hardcodear ninguna credencial
- vas a enfocarte unicamente en la construccion del workflow.




