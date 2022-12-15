DATABASE = '("Apis"[Organism] OR Apis[All Fields]) AND (latest[filter] AND "representative genome"[filter] AND all[filter] NOT anomalous[filter])'


rule create_genome_list:
    output: "list_of_genomes.txt"
    conda:  "entrez_env.yaml"
    
    shell:
        r"""
        mkdir -p temp/

        esearch -db assembly -query '{DATABASE}' \
        | esummary \
        | xtract -pattern DocumentSummary -element FtpPath_GenBank \
        | while read -r line ; 
        do
            fname=$(echo $line | grep -o 'GCA_.*' | sed 's/$/_genomic.fna.gz/');
            wildcard=$(echo $fname | sed -e 's!.fna.gz!!');

            echo "$line/$fname" > temp/$wildcard;
            echo $wildcard >> list_of_genomes.txt

        done
        """

# second rule, a checkpoint for rules that depend on contents of "list_of_genomes.txt"
checkpoint check_genome_list:
    output: touch(".create_genome_list.touch")

    input: "list_of_genomes.txt"


# checkpoint code to read the genome list and specify all wildcards for genomes
class Checkpoint_MakePattern:
    def __init__(self, pattern):
        self.pattern = pattern

    def get_names(self):
        with open('list_of_genomes.txt', 'rt') as fp:
            names = [ x.rstrip() for x in fp ]
        return names

    def __call__(self, w):
        global checkpoints

        # wait for the results of 'list_of_genomes.txt'; this will trigger an
        # exception until that rule has been run.
        checkpoints.check_genome_list.get(**w)

        # information used to expand the pattern, using arbitrary Python code
        names = self.get_names()

        pattern = expand(self.pattern, name=names, **w)

        print(pattern)

        return pattern


rule download_genome:
    output: touch("database/{genome}/{genome}.fna.gz")
    
    input:  "temp/{genome}"

    shell:
        r"""
        GENOME_LINK=$(cat {input})
        GENOME="${{GENOME_LINK##*/}}"
        wget -P ./database/{wildcards.genome}/ $GENOME_LINK 
        """

rule unzip_genome:
    output: "database/{genome}/{genome}.fna"

    input:  "database/{genome}/{genome}.fna.gz"
    
    shell:
        r"""
        gunzip {input}
        """   


rule make_summary_table:
    output: "genomes.txt"
    input:  Checkpoint_MakePattern("database/{name}/{name}.fna")
    #here wildcard has to be named "name", as it must match checkpoint

    shell:
        "echo {input} >> {output}"