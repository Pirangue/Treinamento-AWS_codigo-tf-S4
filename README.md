# Treinamento AWS - Código Terraform S4

Implementação de infraestrutura AWS usando Terraform para provisionar uma instância EC2 com deploy automático de aplicação Docker via user_data.

## 📋 O que será criado

- **VPC** com CIDR 10.0.0.0/16
- **Subnet Pública** com IP público automático
- **Internet Gateway** para acesso externo
- **Security Group** (SSH e HTTP liberados)
- **Key Pair** para autenticação EC2
- **IAM Role** com acesso read-only ao S3
- **EC2** (Amazon Linux 2023) com aplicação Docker

## 🚀 Como usar

### Pré-requisitos
- Terraform instalado
- Credenciais AWS configuradas
- Chave SSH em `~/.ssh/lab-iac.pub`

### Comandos

```bash
# Inicializar Terraform
terraform init

# Validar configuração
terraform plan

# Aplicar infraestrutura
terraform apply
```

## ⚠️ Observações

- A instância está em `us-east-1`
- SSH e HTTP abertos para `0.0.0.0/0` (considere restringir em produção)
- A aplicação Docker é deployada automaticamente via user_data
