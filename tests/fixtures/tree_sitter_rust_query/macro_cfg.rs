#[cfg(feature = "unstable")]
pub fn cfg_only() {}

macro_rules! make_item {
    ($name:ident) => {
        pub fn $name() {}
    };
}

make_item!(from_macro);

pub trait DynTrait {
    fn from_trait(&self);
}
