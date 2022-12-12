# snakemake -j1 -F -p database/GCA_014905175.1_ASM1490517v1_genomic.fna --use-conda


configfile: "config.yaml"
#print("Config is: ", config)

DATABASE = config["database"]
#print(DATABASE)


rule create_genome_list:
    output: touch("temp/{genome}")

    conda:  "entrez_env.yaml"
    message: "Creating the genomes list..."
    
    shell:
        r"""
        esearch -db assembly -query '{DATABASE}' \
        | esummary \
        | xtract -pattern DocumentSummary -element FtpPath_GenBank \
        | while read -r line ; 
        do
            fname=$(echo $line | grep -o 'GCA_.*' | sed 's/$/_genomic.fna.gz/');
            wildcard=$(echo $fname | sed -e 's!.fna.gz!!');

            echo "$line/$fname" > temp/$wildcard;
            #echo $wildcard >> list_of_genomes.txt

        done
       
        """   


rule download_genome:
    output: touch("database/{genome}/{genome}.fna.gz")
    
    input:  "temp/{genome}"

    message: "Downloading genomes..."
    
    shell:
        r"""
        GENOME_LINK=$(cat {input})
        GENOME="${{GENOME_LINK##*/}}"
        wget -P ./database/{wildcards.genome}/ $GENOME_LINK 
        """


rule unzip_genome:
    output: touch("database/{genome}/{genome}.fna")

    input:  "database/{genome}/{genome}.fna.gz"
    
    shell:
        r"""
        gunzip {input}
        """        


GENOMES = os.listdir("temp/")


rule make_summary_table:
    output: "summary_table.txt"

    input:  expand("database/{genome}/{genome}.fna", genome = GENOMES)

    shell:
        """
        echo {input} >> {output}
        echo " " >> {output}
        """