use std::{collections::HashMap, sync::RwLock, time::SystemTime};

use once_cell::sync::Lazy;

#[derive(Debug)]
pub enum ConfigValue {
    String(String),
    Integer(i64),
    Float(f64),
    Boolean(bool),
    Datetime(SystemTime),
    Array(Vec<ConfigValue>),
    Table(HashMap<String, Option<ConfigValue>>),
}

#[derive(Debug, Clone)]
pub struct TomlConfiguration {
    config: config::Config,
}

static CONFIG: Lazy<RwLock<Option<TomlConfiguration>>> = Lazy::new(|| RwLock::new(None));

impl TomlConfiguration {
    pub fn get_config(config_path: &str) -> Self {
        let is_load_needed = {
            let config_lock = CONFIG.read().unwrap();
            config_lock.as_ref().is_none()
        };
        if is_load_needed {
            let mut config_lock = CONFIG.try_write().unwrap();
            let config = Self {
                config: load_config(config_path),
            };
            print_config(&config);
            *config_lock = Some(config);
        }
        let config_lock = CONFIG.read().unwrap();
        config_lock.as_ref().unwrap().clone()
    }

    pub fn get<'a, T>(&self, key: &str) -> Result<T, impl std::error::Error>
    where
        T: serde::Deserialize<'a>,
    {
        self.config.get(key)
    }

    pub fn get_all_avaliable_keys(&self) -> Vec<String> {
        get_keys(&self.config).unwrap()
    }
}

fn print_config(config: &TomlConfiguration) {
    #[cfg(debug_assertions)]
    {
        for (key, value) in config
            .get_all_avaliable_keys()
            .iter()
            .map(|key| (key, config.get::<String>(key).unwrap_or(String::default())))
            .collect::<Vec<_>>()
        {
            println!("{}: {}", key, value);
        }
    }
}

fn load_config(src: &str) -> config::Config {
    use config::{Config, File};
    Config::builder()
        .add_source(File::with_name(src))
        .build()
        .unwrap()
}

fn get_keys(config: &config::Config) -> Result<Vec<String>, config::ConfigError> {
    let config_mapping = config
        .clone()
        .try_deserialize::<HashMap<String, toml::Value>>()?;

    Ok(config_mapping
        .into_iter()
        .flat_map(|kv| recursive_items(&kv, None))
        .collect())
}

fn recursive_items((key, value): &(String, toml::Value), prefix: Option<&str>) -> Vec<String> {
    match value {
        toml::Value::String(_) => vec![join_key(prefix, key)],
        toml::Value::Integer(_) => vec![join_key(prefix, key)],
        toml::Value::Float(_) => vec![join_key(prefix, key)],
        toml::Value::Boolean(_) => vec![join_key(prefix, key)],
        toml::Value::Datetime(_) => vec![join_key(prefix, key)],
        toml::Value::Array(values) => {
            let mut result = Vec::new();
            for (index, value) in values.iter().enumerate() {
                let new_key = join_key(prefix, &format!("{}[{}]", key, index));
                result.append(&mut recursive_items(&(new_key, value.clone()), prefix));
            }
            result
        }
        toml::Value::Table(map) => map
            .iter()
            .flat_map(|(k, v)| {
                recursive_items(
                    &(join_key(prefix, &format!("{}.{}", key, k)), v.clone()),
                    prefix,
                )
            })
            .collect(),
    }
}

fn join_key(prefix: Option<&str>, key: &str) -> String {
    match prefix {
        Some(prefix) => format!("{}.{}", prefix, key),
        None => String::from(key),
    }
}