
configfile: "config.yaml"

DATABASE_QUERY = config["database"]

GENOMES = None

def get_genomes_names(wildcards):
    checkpoint_output = checkpoints.create_genome_list.get(**wildcards).output[0]
    global GENOMES
    GENOMES, = glob_wildcards(os.path.join(checkpoint_output, "{GENOME}.temp"))
    #przecinek oznacza, że będą dwa outputy ale ja chcę zapisać tylko pierwszy... może
    return expand(os.path.join(checkpoint_output, "{GENOME}.temp"), GENOME=GENOMES)

#def get_second_files(wildcards):
#    checkpoint_output = checkpoints.create_genome_list.get(**wildcards).output[0]
#    GENOMES2, = glob_wildcards(os.path.join(checkpoint_output, "{GENOME}.temp"))
#    return expand(os.path.join(SNDDIR, "{SM}.tsv"), SM=GENOMES2)


rule all:
    input: 
        "list_of_files.txt"
        
        
checkpoint create_genome_list:
    output: directory("database_temp")

    conda:  "entrez_env.yaml"
        
    shell:
        """
        mkdir {output};
        
        esearch -db assembly -query '{DATABASE_QUERY}' \
                | esummary \
                | xtract -pattern DocumentSummary -element FtpPath_GenBank \
                | while read -r line ; 
                do
                    fname=$(echo $line | grep -o 'GCA_.*' | sed 's/$/_genomic.fna.gz/');
                    wildcard=$(echo $fname | sed -e 's!.fna.gz!!');

                    echo "$line/$fname" > {output}/$wildcard.temp;
                done

        """

rule download_genome:
    output: directory("database_unzipped/")

    input:  get_genomes_names
    

    shell:
        """
        GENOME_LINK=$(cat {input})
 
        GENOME="${{GENOME_LINK##*/}}"
 
        wget -P {output}/ $GENOME_LINK 
        """


def aggregate_genomes(wildcards):
     checkpoint_output = checkpoints.create_genome_list.get(**wildcards).output[0]
     
     return expand("database_unzipped//{genome}.fna.gz",
                    genome=glob_wildcards(os.path.join(checkpoint_output, "{genome}.fna.gz")).genome)



rule list_all_files:
    output: "list_of_files.txt"

    input:  aggregate_genomes

    shell:
        """
        echo {input}
        """